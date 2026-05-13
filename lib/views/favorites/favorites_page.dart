import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ecomerk2/data/services/navigation_mode_service.dart';
import 'package:ecomerk2/data/services/user_api_service.dart';
import 'package:ecomerk2/data/services/market_api_service.dart';
import 'package:ecomerk2/data/services/pruduct_details_service.dart';
import 'package:ecomerk2/data/services/product_api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/price_alert_button.dart';
import 'widgets/price_history_dialog.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<dynamic> _lista = [];
  bool _loading = true;
  int? _userId;

  // Para comparación de precios
  Map<String, List<dynamic>> _preciosPorProducto = {};
  Map<String, bool> _buscandoPrecio = {};
  Set<String> _expandidos = {};

  @override
  void initState() {
    super.initState();
    _cargarLista();
  }

  Future<void> _cargarLista() async {
    final id = await ApiService.obtenerUserId();
    if (id != null) {
      final usuario = await ApiService.obtenerUsuario(id);
      if (usuario != null && mounted) {
        final favoritosRaw = List<dynamic>.from(
          usuario['favoritos'] ?? usuario['alimentosFavoritos'] ?? [],
        );

        setState(() {
          _userId = id;
          _lista = favoritosRaw;
        });

        // Enriquecer cada favorito con datos frescos del ProductDetailsService
        await _enriquecerFavoritosConDetalles(favoritosRaw);

        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }

  /// Consulta ProductDetailsService para cada favorito que tenga productId,
  /// actualizando nombre, precio, imagen y link con datos frescos de la tienda.
  /// El productId se almacena en formato "tienda::id" para poder recuperar ambos valores.
  Future<void> _enriquecerFavoritosConDetalles(List<dynamic> favoritos) async {
    final List<dynamic> listaActualizada = List.from(favoritos);
    bool huboActualizacion = false;

    await Future.wait(
      listaActualizada.asMap().entries.map((entry) async {
        final i = entry.key;
        final item = entry.value;
        if (item is! Map) return;

        final String rawProductId = (item['productId'] ?? '').toString();
        if (rawProductId.isEmpty) return;

        // Parsear formato "tienda::id"
        String tienda = '';
        String productId = rawProductId;
        if (rawProductId.contains('::')) {
          final parts = rawProductId.split('::');
          tienda = parts[0];
          productId = parts.sublist(1).join('::'); // Por si el id contiene ::
        }

        if (productId.isEmpty || tienda.isEmpty) return;

        try {
          final detalles = await ProductDetailsService.consultarProductoPorId(
            productId,
            tienda,
          );

          if (detalles != null) {
            listaActualizada[i] = {
              ...Map<String, dynamic>.from(item),
              'nombre': detalles['nombre'] ?? item['nombre'],
              'precio': '\$${_formatearPrecio(detalles['precio'] as double)}',
              'imagen': detalles['imagen'] ?? item['imagen'],
              'link': detalles['link'] ?? item['link'],
              'tienda': detalles['tienda'] ?? tienda,
              'productId': rawProductId,
              'notificaciones': item['notificaciones'] ?? false,
            };
            huboActualizacion = true;

            // Enviar precio fresco al historial de precios
            final double? precioFresco = detalles['precio'] is double
                ? detalles['precio'] as double
                : null;
            if (precioFresco != null && precioFresco > 0) {
              ProductApiService.agregarPrecio(
                productId: rawProductId,
                precio: precioFresco,
              );
            }
          }
        } catch (e) {
          debugPrint('Error enriqueciendo favorito $rawProductId: $e');
        }
      }),
    );

    if (huboActualizacion && mounted) {
      setState(() {
        _lista = listaActualizada;
      });
    }
  }

  Future<void> _eliminarProducto(int index) async {
    final item = _lista[index];
    final nombre = item is Map
        ? (item['nombre'] ?? 'Producto')
        : item.toString();

    final nuevaLista = [..._lista];
    nuevaLista.removeAt(index);
    setState(() {
      _lista = nuevaLista;
      _preciosPorProducto.remove(nombre);
      _expandidos.remove(nombre);
      _buscandoPrecio.remove(nombre);
    });

    if (_userId != null) {
      await ApiService.actualizarLista(_userId!, nuevaLista);
    }
  }

  /// Simplifica el nombre de un producto para obtener mejores resultados
  /// de búsqueda. Toma las primeras 3-4 palabras significativas y descarta
  /// unidades, cantidades y caracteres especiales que causan que la API de
  /// Éxito (VTEX ft=) no devuelva resultados.
  String _simplificarBusqueda(String nombre) {
    // Palabras/patrones que no aportan a la búsqueda
    final stopPatterns = RegExp(
      r'\b(\d+\s*(ml|g|kg|l|lt|cc|oz|lb|und|un|pack|x\d+))\b|[\-–—/()]',
      caseSensitive: false,
    );
    String limpio = nombre.replaceAll(stopPatterns, ' ').trim();
    final palabras = limpio.split(RegExp(r'\s+')).where((p) => p.length > 1).toList();
    // Tomamos máximo 4 palabras significativas
    final corte = palabras.length > 4 ? 4 : palabras.length;
    return palabras.take(corte).join(' ');
  }

  Future<void> _compararPrecios(String producto) async {
    if (_buscandoPrecio[producto] == true) return;

    setState(() {
      _buscandoPrecio[producto] = true;
      _expandidos.add(producto);
    });

    try {
      // Simplificar el nombre para mejorar resultados en todas las tiendas
      final querySimplificado = _simplificarBusqueda(producto);
      final resultados = await MarketApiService.buscarEnTiendas(querySimplificado);
      if (mounted) {
        final Set<String> tiendasVistas = {};
        final List<dynamic> masBaratosPorTienda = [];

        for (final r in resultados) {
          final String tienda = (r['tienda'] ?? '').toString().toLowerCase();
          if (!tiendasVistas.contains(tienda)) {
            tiendasVistas.add(tienda);
            masBaratosPorTienda.add(r);
          }
        }

        setState(() {
          _preciosPorProducto[producto] = masBaratosPorTienda.take(4).toList();
          _buscandoPrecio[producto] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _buscandoPrecio[producto] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al buscar precios')),
        );
      }
    }
  }

  String _formatearPrecio(double precio) {
    return precio
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  // Busca todos los productos de la lista de una vez
  Future<void> _compararTodos() async {
    for (final item in _lista) {
      final nombre = item is Map
          ? (item['nombre'] ?? 'Producto')
          : item.toString();
      if (_preciosPorProducto[nombre] == null) {
        await _compararPrecios(nombre);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usarMenuLateral = NavigationModeService.instance.isDrawerMode;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: usarMenuLateral
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.go('/home'),
              )
            : null,
        title: const Text(
          'Mi lista de compras',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1D9E75),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_lista.isNotEmpty)
            TextButton.icon(
              onPressed: _compararTodos,
              icon: const Icon(
                Icons.compare_arrows,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Comparar todo',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
            )
          : Column(
              children: [
                // Resumen si hay items
                if (_lista.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D9E75).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF1D9E75).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_basket_outlined,
                          color: Color(0xFF1D9E75),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_lista.length} producto${_lista.length != 1 ? 's' : ''} en tu lista',
                          style: const TextStyle(
                            color: Color(0xFF1D9E75),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Desliza para eliminar',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                // Lista
                Expanded(
                  child: _lista.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('🛒', style: TextStyle(fontSize: 64)),
                              SizedBox(height: 16),
                              Text(
                                'Tu lista está vacía',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF444441),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Agrega productos desde la sección de búsqueda\npara tenerlos aquí',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _lista.length,
                          itemBuilder: (context, index) {
                            final item = _lista[index];
                            final isMap = item is Map;
                            final nombreProducto = isMap
                                ? (item['nombre'] ?? 'Producto')
                                : item.toString();

                            final precios = _preciosPorProducto[nombreProducto];
                            final buscando =
                                _buscandoPrecio[nombreProducto] == true;
                            final expandido = _expandidos.contains(
                              nombreProducto,
                            );

                            return Dismissible(
                              key: Key('$index-$nombreProducto'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.delete, color: Colors.white),
                                    SizedBox(height: 4),
                                    Text(
                                      'Eliminar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              onDismissed: (_) => _eliminarProducto(index),
                              child: GestureDetector(
                                onTap: () async {
                                  if (isMap &&
                                      item['link'] != null &&
                                      item['link'].toString().isNotEmpty) {
                                    final url = Uri.parse(
                                      item['link'].toString(),
                                    );
                                    try {
                                      await launchUrl(
                                        url,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    } catch (_) {}
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Fila principal del producto
                                      Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          children: [
                                            if (isMap &&
                                                (item['imagen']
                                                        ?.toString()
                                                        .isNotEmpty ??
                                                    false))
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Image.network(
                                                  item['imagen'],
                                                  width: 42,
                                                  height: 42,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                      _buildIconPlaceholder(),
                                                ),
                                              )
                                            else
                                              _buildIconPlaceholder(),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    nombreProducto,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF2C2C2A),
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (isMap &&
                                                      item['precio'] != null &&
                                                      item['precio'] != "\$0")
                                                    Text(
                                                      'Guardado a: ${item['precio']} · ${item['tienda'] ?? ''}',
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  if (precios != null &&
                                                      precios.isNotEmpty)
                                                    Text(
                                                      '${isMap && item['precio'] != null && item['precio'] != "\$0" ? "Mejor opción" : "Desde"}: \$${_formatearPrecio(precios[0]['precio'] as double)} · ${precios[0]['tienda']}',
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF1D9E75,
                                                        ),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // Botones de acción (historial + notificaciones)
                                            // ── Botón historial de precios ──
                                            GestureDetector(
                                              onTap: () {
                                                final pid = isMap
                                                    ? (item['productId'] ?? item['link'] ?? item['nombre'] ?? '')
                                                        .toString()
                                                    : nombreProducto;
                                                PriceHistoryDialog.show(
                                                  context,
                                                  productId: pid,
                                                  productName: nombreProducto,
                                                );
                                              },
                                              child: Tooltip(
                                                message: 'Ver historial de precios',
                                                child: Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.timeline_rounded,
                                                    color: Color(0xFF3B82F6),
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // ── Botón alerta de precio ──
                                            PriceAlertButton(
                                              nombreProducto: nombreProducto,
                                              precioReferencia: isMap &&
                                                      item['precio'] != null &&
                                                      item['precio'] != r'$0'
                                                  ? double.tryParse(
                                                      item['precio']
                                                          .toString()
                                                          .replaceAll(r'$', '')
                                                          .replaceAll('.', '')
                                                          .trim(),
                                                    )
                                                  : null,
                                              onToggle: (suscrito) {
                                                // Sincronizar el campo notificaciones con el backend
                                                if (isMap && _userId != null) {
                                                  setState(() {
                                                    _lista[index]['notificaciones'] = suscrito;
                                                  });
                                                  ApiService.actualizarLista(_userId!, _lista);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      // ── Botón comparar (fila completa debajo) ──
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                                        child: !buscando
                                            ? GestureDetector(
                                                onTap: () => precios != null
                                                    ? setState(() {
                                                        if (expandido) {
                                                          _expandidos.remove(
                                                            nombreProducto,
                                                          );
                                                        } else {
                                                          _expandidos.add(
                                                            nombreProducto,
                                                          );
                                                        }
                                                      })
                                                    : _compararPrecios(
                                                        nombreProducto,
                                                      ),
                                                child: Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: precios != null
                                                        ? const Color(
                                                            0xFF1D9E75,
                                                          ).withOpacity(0.1)
                                                        : const Color(
                                                            0xFF1D9E75,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        precios != null
                                                            ? (expandido
                                                                  ? Icons
                                                                        .keyboard_arrow_up
                                                                  : Icons
                                                                        .keyboard_arrow_down)
                                                            : Icons
                                                                  .compare_arrows,
                                                        color: precios != null
                                                            ? const Color(
                                                                0xFF1D9E75,
                                                              )
                                                            : Colors.white,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        precios != null
                                                            ? (expandido
                                                                  ? 'Ocultar comparación'
                                                                  : 'Ver comparación de precios')
                                                            : 'Comparar precios en tiendas',
                                                        style: TextStyle(
                                                          color: precios != null
                                                              ? const Color(
                                                                  0xFF1D9E75,
                                                                )
                                                              : Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : const Center(
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(vertical: 4),
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Color(
                                                            0xFF1D9E75,
                                                          ),
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                      ),

                                      // Panel de comparación expandible
                                      if (expandido && precios != null)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FFFE),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  bottom: Radius.circular(16),
                                                ),
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey.shade100,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      14,
                                                      12,
                                                      14,
                                                      8,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.storefront,
                                                      size: 14,
                                                      color: Colors.grey,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Comparación de precios · ${precios.length} resultado${precios.length != 1 ? 's' : ''}',
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (precios.isEmpty)
                                                const Padding(
                                                  padding: EdgeInsets.all(16),
                                                  child: Text(
                                                    'No se encontraron precios para este producto',
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                )
                                              else
                                                ...precios.asMap().entries.map((
                                                  entry,
                                                ) {
                                                  final i = entry.key;
                                                  final p = entry.value;
                                                  final esMasBarato = i == 0;
                                                  return GestureDetector(
                                                    onTap: () async {
                                                      final url = Uri.parse(
                                                        p['link'] ?? '',
                                                      );
                                                      try {
                                                        await launchUrl(
                                                          url,
                                                          mode: LaunchMode
                                                              .externalApplication,
                                                        );
                                                      } catch (_) {}
                                                    },
                                                    child: Container(
                                                      margin:
                                                          const EdgeInsets.fromLTRB(
                                                            14,
                                                            0,
                                                            14,
                                                            8,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: esMasBarato
                                                            ? const Color(
                                                                0xFF1D9E75,
                                                              ).withOpacity(
                                                                0.08,
                                                              )
                                                            : Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: esMasBarato
                                                              ? const Color(
                                                                  0xFF1D9E75,
                                                                )
                                                              : Colors
                                                                    .grey
                                                                    .shade200,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          // Imagen del producto
                                                          ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            child: Image.network(
                                                              p['imagen'] ?? '',
                                                              width: 48,
                                                              height: 48,
                                                              fit: BoxFit
                                                                  .contain,
                                                              errorBuilder:
                                                                  (
                                                                    _,
                                                                    __,
                                                                    ___,
                                                                  ) => Container(
                                                                    width: 48,
                                                                    height: 48,
                                                                    color: Colors
                                                                        .grey[100],
                                                                    child: const Icon(
                                                                      Icons
                                                                          .image_not_supported,
                                                                      color: Colors
                                                                          .grey,
                                                                      size: 20,
                                                                    ),
                                                                  ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  p['nombre'] ??
                                                                      '',
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    const Icon(
                                                                      Icons
                                                                          .store,
                                                                      size: 11,
                                                                      color: Colors
                                                                          .grey,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 3,
                                                                    ),
                                                                    Text(
                                                                      p['tienda']
                                                                          .toString()
                                                                          .toUpperCase(),
                                                                      style: TextStyle(
                                                                        color: Colors
                                                                            .grey[600],
                                                                        fontSize:
                                                                            10,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        letterSpacing:
                                                                            0.5,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end,
                                                            children: [
                                                              Text(
                                                                '\$${_formatearPrecio(p['precio'] as double)}',
                                                                style: TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  color:
                                                                      esMasBarato
                                                                      ? const Color(
                                                                          0xFF1D9E75,
                                                                        )
                                                                      : const Color(
                                                                          0xFF2C2C2A,
                                                                        ),
                                                                ),
                                                              ),
                                                              if (esMasBarato)
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(
                                                                      0xFF1D9E75,
                                                                    ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          4,
                                                                        ),
                                                                  ),
                                                                  child: const Text(
                                                                    '+ barato',
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          9,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              const Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .open_in_new,
                                                                    size: 10,
                                                                    color: Colors
                                                                        .grey,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 2,
                                                                  ),
                                                                  Text(
                                                                    'Ver',
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .grey,
                                                                      fontSize:
                                                                          10,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              const SizedBox(height: 6),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildIconPlaceholder() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF1D9E75).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.shopping_cart_outlined,
        color: Color(0xFF1D9E75),
        size: 20,
      ),
    );
  }
}
