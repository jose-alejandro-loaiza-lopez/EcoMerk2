import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ecomerk2/data/services/navigation_mode_service.dart';
import 'package:ecomerk2/data/services/user_api_service.dart';
import 'package:ecomerk2/data/services/market_api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/price_alert_button.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<dynamic> _lista = [];
  bool _loading = true;
  int? _userId;

  // Caché de datos enriquecidos por link: { link → {nombre, imagen, precio, tienda} }
  final Map<String, Map<String, dynamic>> _datosProducto = {};
  // Qué links están siendo enriquecidos ahora
  final Set<String> _enriqueciendo = {};

  // Para comparación de precios (keyed por link)
  final Map<String, List<dynamic>> _preciosPorProducto = {};
  final Map<String, bool> _buscandoPrecio = {};
  final Set<String> _expandidos = {};

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
        final lista = List<dynamic>.from(
          usuario['favoritos'] ?? usuario['alimentosFavoritos'] ?? [],
        );
        setState(() {
          _userId = id;
          _lista = lista;
          _loading = false;
        });
        // Enriquecer todos los productos en paralelo
        _enriquecerTodos();
      }
    }
    if (mounted && _loading) {
      setState(() => _loading = false);
    }
  }

  /// Lanza el enriquecimiento de todos los items de la lista en paralelo.
  void _enriquecerTodos() {
    for (final item in _lista) {
      final link = _obtenerLink(item);
      if (link.isNotEmpty && !_datosProducto.containsKey(link)) {
        _enriquecerProducto(link);
      }
    }
  }

  /// Consulta el API de la tienda por el link y guarda los datos en caché.
  Future<void> _enriquecerProducto(String link) async {
    if (_enriqueciendo.contains(link)) return;
    if (mounted) setState(() => _enriqueciendo.add(link));

    try {
      final datos = await MarketApiService.obtenerProductoPorLink(link);
      if (mounted) {
        setState(() {
          _enriqueciendo.remove(link);
          if (datos != null) {
            _datosProducto[link] = datos;
          } else {
            // Guardar placeholder para no reintentar indefinidamente
            _datosProducto[link] = {'nombre': '', 'imagen': '', 'precio': 0.0, 'tienda': ''};
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _enriqueciendo.remove(link));
    }
  }

  /// Extrae el link de un item de la lista (puede ser Map o String).
  String _obtenerLink(dynamic item) {
    if (item is Map) return (item['link'] ?? '').toString();
    return item.toString();
  }

  Future<void> _eliminarProducto(int index) async {
    final item = _lista[index];
    final link = _obtenerLink(item);

    final nuevaLista = [..._lista];
    nuevaLista.removeAt(index);
    setState(() {
      _lista = nuevaLista;
      _datosProducto.remove(link);
      _preciosPorProducto.remove(link);
      _expandidos.remove(link);
      _buscandoPrecio.remove(link);
      _enriqueciendo.remove(link);
    });

    if (_userId != null) {
      await ApiService.actualizarLista(_userId!, nuevaLista);
    }
  }

  Future<void> _compararPrecios(String link, String nombreBusqueda) async {
    if (_buscandoPrecio[link] == true) return;

    setState(() {
      _buscandoPrecio[link] = true;
      _expandidos.add(link);
    });

    try {
      final resultados = await MarketApiService.buscarEnTiendas(nombreBusqueda);
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
          _preciosPorProducto[link] = masBaratosPorTienda.take(4).toList();
          _buscandoPrecio[link] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _buscandoPrecio[link] = false);
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

  Future<void> _compararTodos() async {
    for (final item in _lista) {
      final link = _obtenerLink(item);
      final datos = _datosProducto[link];
      final nombre = (datos?['nombre'] as String?)?.isNotEmpty == true
          ? datos!['nombre'] as String
          : link;
      if (_preciosPorProducto[link] == null && nombre.isNotEmpty) {
        await _compararPrecios(link, nombre);
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
                      color: const Color(0xFF1D9E75).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF1D9E75).withValues(alpha: 0.3),
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
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
                            final link = _obtenerLink(item);
                            final cargando = _enriqueciendo.contains(link);
                            final datos = _datosProducto[link];

                            // Nombre: datos enriquecidos → fallback a placeholder mientras carga
                            final nombre = (datos?['nombre'] as String?)?.isNotEmpty == true
                                ? datos!['nombre'] as String
                                : (cargando ? 'Cargando...' : 'Producto sin nombre');
                            final imagen = (datos?['imagen'] as String?) ?? '';
                            final precioNum = (datos?['precio'] as num?)?.toDouble() ?? 0.0;
                            final tienda = (datos?['tienda'] as String?) ?? '';

                            final precios = _preciosPorProducto[link];
                            final buscando = _buscandoPrecio[link] == true;
                            final expandido = _expandidos.contains(link);

                            return Dismissible(
                              key: Key(link.isNotEmpty ? link : '$index'),
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
                                  if (link.isNotEmpty) {
                                    final url = Uri.parse(link);
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
                                        color: Colors.black.withValues(alpha: 0.05),
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
                                            // Imagen o skeleton
                                            _buildProductImage(imagen, cargando),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  cargando
                                                      ? _buildSkeletonText(width: 140, height: 14)
                                                      : Text(
                                                          nombre,
                                                          style: const TextStyle(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.w600,
                                                            color: Color(0xFF2C2C2A),
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                  const SizedBox(height: 4),
                                                  if (!cargando && precioNum > 0)
                                                    Text(
                                                      'Guardado a: \$${_formatearPrecio(precioNum)} · $tienda',
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  if (cargando && precioNum == 0)
                                                    _buildSkeletonText(width: 100, height: 11),
                                                  if (precios != null && precios.isNotEmpty)
                                                    Text(
                                                      '${precioNum > 0 ? "Mejor opción" : "Desde"}: \$${_formatearPrecio(precios[0]['precio'] as double)} · ${precios[0]['tienda']}',
                                                      style: const TextStyle(
                                                        color: Color(0xFF1D9E75),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // ── Botón alerta de precio ──
                                            if (!cargando && link.isNotEmpty)
                                              PriceAlertButton(
                                                productLink: link,
                                                nombreProducto: nombre,
                                                precioReferencia: precioNum > 0 ? precioNum : null,
                                              ),
                                            const SizedBox(width: 6),
                                            // ── Botón comparar ──
                                            if (!cargando && nombre.isNotEmpty)
                                              if (!buscando) ...[
                                                GestureDetector(
                                                  onTap: () => precios != null
                                                      ? setState(() {
                                                          if (expandido) {
                                                            _expandidos.remove(link);
                                                          } else {
                                                            _expandidos.add(link);
                                                          }
                                                        })
                                                      : _compararPrecios(link, nombre),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: precios != null
                                                          ? const Color(0xFF1D9E75)
                                                              .withValues(alpha: 0.1)
                                                          : const Color(0xFF1D9E75),
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          precios != null
                                                              ? (expandido
                                                                    ? Icons.keyboard_arrow_up
                                                                    : Icons.keyboard_arrow_down)
                                                              : Icons.compare_arrows,
                                                          color: precios != null
                                                              ? const Color(0xFF1D9E75)
                                                              : Colors.white,
                                                          size: 16,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          precios != null
                                                              ? (expandido ? 'Ocultar' : 'Ver precios')
                                                              : 'Comparar',
                                                          style: TextStyle(
                                                            color: precios != null
                                                                ? const Color(0xFF1D9E75)
                                                                : Colors.white,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ] else
                                                const SizedBox(
                                                  width: 80,
                                                  child: Center(
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        color: Color(0xFF1D9E75),
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                          ],
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
                                                      14, 12, 14, 8,
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
                                                        fontWeight: FontWeight.w500,
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
                                                ...precios.asMap().entries.map((entry) {
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
                                                          mode: LaunchMode.externalApplication,
                                                        );
                                                      } catch (_) {}
                                                    },
                                                    child: Container(
                                                      margin: const EdgeInsets.fromLTRB(
                                                        14, 0, 14, 8,
                                                      ),
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: esMasBarato
                                                            ? const Color(0xFF1D9E75)
                                                                .withValues(alpha: 0.08)
                                                            : Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(10),
                                                        border: Border.all(
                                                          color: esMasBarato
                                                              ? const Color(0xFF1D9E75)
                                                              : Colors.grey.shade200,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          // Imagen del producto
                                                          ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(8),
                                                            child: Image.network(
                                                              p['imagen'] ?? '',
                                                              width: 48,
                                                              height: 48,
                                                              fit: BoxFit.contain,
                                                              errorBuilder: (context, error, stackTrace) =>
                                                                  Container(
                                                                    width: 48,
                                                                    height: 48,
                                                                    color: Colors.grey[100],
                                                                    child: const Icon(
                                                                      Icons.image_not_supported,
                                                                      color: Colors.grey,
                                                                      size: 20,
                                                                    ),
                                                                  ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 10),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  p['nombre'] ?? '',
                                                                  style: const TextStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                const SizedBox(height: 2),
                                                                Row(
                                                                  children: [
                                                                    const Icon(
                                                                      Icons.store,
                                                                      size: 11,
                                                                      color: Colors.grey,
                                                                    ),
                                                                    const SizedBox(width: 3),
                                                                    Text(
                                                                      p['tienda'].toString().toUpperCase(),
                                                                      style: TextStyle(
                                                                        color: Colors.grey[600],
                                                                        fontSize: 10,
                                                                        fontWeight: FontWeight.bold,
                                                                        letterSpacing: 0.5,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment.end,
                                                            children: [
                                                              Text(
                                                                '\$${_formatearPrecio(p['precio'] as double)}',
                                                                style: TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight: FontWeight.w900,
                                                                  color: esMasBarato
                                                                      ? const Color(0xFF1D9E75)
                                                                      : const Color(0xFF2C2C2A),
                                                                ),
                                                              ),
                                                              if (esMasBarato)
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(
                                                                    horizontal: 6,
                                                                    vertical: 2,
                                                                  ),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFF1D9E75),
                                                                    borderRadius:
                                                                        BorderRadius.circular(4),
                                                                  ),
                                                                  child: const Text(
                                                                    '+ barato',
                                                                    style: TextStyle(
                                                                      color: Colors.white,
                                                                      fontSize: 9,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                              const SizedBox(height: 4),
                                                              const Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons.open_in_new,
                                                                    size: 10,
                                                                    color: Colors.grey,
                                                                  ),
                                                                  SizedBox(width: 2),
                                                                  Text(
                                                                    'Ver',
                                                                    style: TextStyle(
                                                                      color: Colors.grey,
                                                                      fontSize: 10,
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

  /// Muestra la imagen del producto o un skeleton/placeholder mientras carga.
  Widget _buildProductImage(String imagen, bool cargando) {
    if (cargando) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Color(0xFF1D9E75),
            ),
          ),
        ),
      );
    }
    if (imagen.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          imagen,
          width: 42,
          height: 42,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => _buildIconPlaceholder(),
        ),
      );
    }
    return _buildIconPlaceholder();
  }

  /// Skeleton animado para el texto mientras carga.
  Widget _buildSkeletonText({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildIconPlaceholder() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF1D9E75).withValues(alpha: 0.1),
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
