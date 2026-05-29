import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:ecomerk2/data/services/navigation_mode_service.dart';
import 'package:ecomerk2/data/services/market_api_service.dart';
import 'package:ecomerk2/data/services/user_api_service.dart';
import 'package:ecomerk2/data/services/product_api_service.dart';
import 'package:ecomerk2/data/services/local_inference_service.dart';
import 'package:ecomerk2/data/services/chat_api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery;
  const SearchPage({super.key, this.initialQuery});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _todosResultados = [];
  List<dynamic> _resultadosFiltrados = [];
  bool _cargando = false;
  String _ordenSeleccionado = 'OrderByScoreDESC';
  Set<String> _tiendasSeleccionadas = {};
  Set<String> _enFavoritos = {};

  final TextEditingController _listaController = TextEditingController();
  List<String> _listaCompras = [];
  bool _procesandoLista = false;
  bool _buscandoEnTiendas = false;
  String? _respuestaLista;

  @override
  void initState() {
    super.initState();
    _cargarFavoritosPreviamenteGuardados();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ejecutarBusqueda(nuevaBusqueda: true);
      });
    }
  }

  @override
  void dispose() {
    _listaController.dispose();
    super.dispose();
  }

  Future<void> _cargarFavoritosPreviamenteGuardados() async {
    try {
      final id = await ApiService.obtenerUserId();
      if (id != null) {
        final usuario = await ApiService.obtenerUsuario(id);
        if (usuario != null && mounted) {
          final favs = List<dynamic>.from(
            usuario['favoritos'] ?? usuario['alimentosFavoritos'] ?? [],
          );
          setState(() {
            _enFavoritos = favs.map((f) {
              if (f is Map) {
                // Parsear formato "tienda::id"
                final rawProductId = f['productId']?.toString();
                if (rawProductId != null && rawProductId.isNotEmpty) {
                  String productId = rawProductId;
                  if (rawProductId.contains('::')) {
                    final parts = rawProductId.split('::');
                    productId = parts
                        .sublist(1)
                        .join('::'); // Por si el id contiene ::
                  }
                  return productId;
                }
                return (f['link'] ?? f['nombre']).toString();
              }
              return f.toString();
            }).toSet();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _ejecutarBusqueda({bool nuevaBusqueda = true}) async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      _cargando = true;
      _todosResultados = [];
      _resultadosFiltrados = [];
      if (nuevaBusqueda) {
        _tiendasSeleccionadas.clear();
      }
    });

    try {
      final data = await MarketApiService.buscarEnTiendas(
        texto,
        orden: _ordenSeleccionado,
      );
      setState(() {
        _todosResultados = data;
        _aplicarFiltros();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al conectar con los supermercados'),
          ),
        );
      }
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _aplicarFiltros() {
    List<dynamic> resultado = List.from(_todosResultados);

    if (_tiendasSeleccionadas.isNotEmpty) {
      resultado = resultado
          .where((p) => _tiendasSeleccionadas.contains(p['tienda']))
          .toList();
    }

    setState(() => _resultadosFiltrados = resultado);
  }

  String _formatearPrecio(double precio) {
    return precio
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  String _calcularAhorro(double precio) {
    if (_todosResultados.isEmpty) return '';

    double sumaPrecios = _todosResultados
        .map((p) => p['precio'] as double)
        .reduce((a, b) => a + b);

    double promedio = sumaPrecios / _todosResultados.length;

    if (precio >= promedio) return '';

    final ahorro = promedio - precio;

    return 'Ahorras \$${_formatearPrecio(ahorro)}';
  }

  List<String> get _tiendas {
    return _todosResultados.map((p) => p['tienda'] as String).toSet().toList();
  }

  Future<void> _toggleFavorito(Map<String, dynamic> item) async {
    try {
      final id = await ApiService.obtenerUserId();
      if (id == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes iniciar sesión para editar favoritos'),
            ),
          );
        }
        return;
      }

      final usuario = await ApiService.obtenerUsuario(id);
      if (usuario == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al obtener usuario')),
          );
        }
        return;
      }

      List<dynamic> favoritosActuales = List.from(
        usuario['favoritos'] ?? usuario['alimentosFavoritos'] ?? [],
      );

      final itemLink = item['link'];
      final itemNombre = item['nombre'];

      final String rawId = item['id']?.toString().isNotEmpty == true
          ? item['id'].toString()
          : (itemLink ?? itemNombre ?? '');
      final String tiendaTag = (item['tienda'] ?? '').toString();
      final String compoundId = tiendaTag.isNotEmpty
          ? '$tiendaTag::$rawId'
          : rawId;

      // Verificar si ya existe buscando por el id parseado, link o nombre
      int indexExiste = favoritosActuales.indexWhere((favorito) {
        if (favorito is Map) {
          final rawProductId = favorito['productId']?.toString();
          if (rawProductId != null && rawProductId.isNotEmpty) {
            String favId = rawProductId;
            if (rawProductId.contains('::')) {
              final parts = rawProductId.split('::');
              favId = parts.sublist(1).join('::');
            }
            if (favId == rawId) return true;
          }
          return favorito['link'] == itemLink ||
              favorito['nombre'] == itemNombre;
        }
        return favorito == itemNombre;
      });

      if (indexExiste != -1) {
        // Quitar de favoritos
        favoritosActuales.removeAt(indexExiste);
        final exito = await ApiService.actualizarLista(id, favoritosActuales);

        if (mounted) {
          if (exito) {
            setState(() {
              _enFavoritos.remove(rawId);
              _enFavoritos.remove(itemLink?.toString() ?? '');
              _enFavoritos.remove(itemNombre?.toString() ?? '');
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Producto quitado de favoritos')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al quitar de favoritos')),
            );
          }
        }
      } else {
        // Agregar a favoritos

        bool? hasProtein;
        String? proteinLabel;
        if (LocalInferenceService.isAvailable) {
          try {
            final imageUrl = item['imagen']?.toString() ?? '';
            if (imageUrl.isNotEmpty) {
              hasProtein = await LocalInferenceService.hasProtein(imageUrl);
              proteinLabel = hasProtein ? 'Con proteína' : 'Sin proteína';
            }
          } catch (e) {
            debugPrint('Protein inference failed for $itemNombre: $e');
            proteinLabel = 'Inferencia falló';
          }
        }

        final productoFavorito = {
          "productId": compoundId,
          "nombre": itemNombre,
          "precio": "\$${_formatearPrecio(item['precio'] as double)}",
          "tienda": item['tienda'],
          "imagen": item['imagen'],
          "link": itemLink,
          "notificaciones": false,
          if (hasProtein != null) "hasProtein": hasProtein,
        };

        favoritosActuales.add(productoFavorito);
        final exito = await ApiService.actualizarLista(id, favoritosActuales);

        if (mounted) {
          if (exito) {
            setState(() {
              _enFavoritos.add(rawId);
              _enFavoritos.add(
                itemLink?.toString() ?? itemNombre?.toString() ?? '',
              );
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  proteinLabel != null
                      ? 'Agregado · $proteinLabel'
                      : 'Producto agregado a favoritos',
                ),
                backgroundColor: const Color(0xFF1D9E75),
              ),
            );

            // Enviar precio al historial de precios automáticamente
            final double? precioNum = item['precio'] is double
                ? item['precio'] as double
                : double.tryParse(
                    item['precio']
                        .toString()
                        .replaceAll(r'$', '')
                        .replaceAll('.', '')
                        .trim(),
                  );
            if (precioNum != null && precioNum > 0) {
              ProductApiService.agregarPrecio(
                productId: compoundId,
                precio: precioNum,
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al agregar a favoritos')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al modificar favoritos')),
        );
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
          'Buscar en Tuluá',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1D9E75),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Buscador
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Ej: Arroz, Café, Leche...',
                          prefixIcon: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Color(0xFF1D9E75),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF1D9E75),
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: (_) =>
                            _ejecutarBusqueda(nuevaBusqueda: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _cargando
                          ? null
                          : () => _ejecutarBusqueda(nuevaBusqueda: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D9E75),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      child: const Icon(Icons.search, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Filtros
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        'Ordenar: ',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      _buildFiltroChip('Relevancia', 'OrderByScoreDESC'),
                      const SizedBox(width: 8),
                      _buildFiltroChip('Más barato', 'OrderByPriceASC'),
                      if (_tiendas.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        const Text(
                          'Tienda: ',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        ..._tiendas.map(
                          (tienda) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(tienda),
                              selected: _tiendasSeleccionadas.contains(tienda),
                              selectedColor: const Color(
                                0xFF1D9E75,
                              ).withOpacity(0.2),
                              checkmarkColor: const Color(0xFF1D9E75),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _tiendasSeleccionadas.add(tienda);
                                  } else {
                                    _tiendasSeleccionadas.remove(tienda);
                                  }
                                });
                                _aplicarFiltros();
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contador de resultados
          if (_resultadosFiltrados.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_resultadosFiltrados.length} resultados encontrados',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Cargando
          if (_cargando)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF1D9E75)),
                    SizedBox(height: 16),
                    Text(
                      'Buscando en supermercados...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

          // Sin resultados
          if (!_cargando &&
              _resultadosFiltrados.isEmpty &&
              _todosResultados.isEmpty &&
              _controller.text.isNotEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🔍', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 16),
                    Text(
                      'No encontramos productos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Intenta con otro término de búsqueda',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

          // Estado inicial con lista de compras o respuesta IA
          if (!_cargando && _controller.text.isEmpty)
            Expanded(
              child: _respuestaLista != null
                  ? _buildRespuestaLista()
                  : _buildListaCompras(),
            ),

          // Lista de resultados
          if (!_cargando && _resultadosFiltrados.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _resultadosFiltrados.length,
                itemBuilder: (context, index) {
                  final item = _resultadosFiltrados[index];
                  final ahorro = _calcularAhorro(item['precio'] as double);
                  final esMasBarato = ahorro.isNotEmpty;
                  final String rawId = item['id']?.toString().isNotEmpty == true
                      ? item['id'].toString()
                      : (item['link'] ?? item['nombre'] ?? '');
                  final esFavorito =
                      _enFavoritos.contains(rawId) ||
                      _enFavoritos.contains(item['link']) ||
                      _enFavoritos.contains(item['nombre']);

                  return GestureDetector(
                    onTap: () async {
                      final url = Uri.parse(item['link'] ?? '');
                      try {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo abrir el producto'),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: esMasBarato
                            ? Border.all(
                                color: const Color(0xFF1D9E75),
                                width: 2,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge "Más barato"
                          if (esMasBarato)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 12,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1D9E75),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.local_offer,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '¡Más barato! $ahorro',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Imagen
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    item['imagen'] ?? '',
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 90,
                                      height: 90,
                                      color: Colors.grey[100],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Nombre
                                      Text(
                                        item['nombre'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      // Marca
                                      if (item['marca'] != null &&
                                          item['marca'].toString().isNotEmpty)
                                        Text(
                                          item['marca'].toString(),
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      // Precio
                                      Text(
                                        '\$${_formatearPrecio(item['precio'] as double)}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          color: Color(0xFF1D9E75),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Tienda
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.store,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            item['tienda']
                                                .toString()
                                                .toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Fecha de actualización
                                      if (item['fechaActualizacion'] != null &&
                                          item['fechaActualizacion']
                                              .toString()
                                              .isNotEmpty)
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.update,
                                              size: 12,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Act: ${item['fechaActualizacion']}',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 4),
                                      // Ver en tienda
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.open_in_new,
                                                size: 12,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'Ver en tienda',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              esFavorito
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: const Color(0xFF1D9E75),
                                              size: 20,
                                            ),
                                            onPressed: () => _toggleFavorito(
                                              item as Map<String, dynamic>,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildFiltroChip(String label, String valor) {
    return FilterChip(
      label: Text(label),
      selected: _ordenSeleccionado == valor,
      selectedColor: const Color(0xFF1D9E75).withOpacity(0.2),
      checkmarkColor: const Color(0xFF1D9E75),
      onSelected: (selected) {
        if (_ordenSeleccionado != valor) {
          setState(() => _ordenSeleccionado = valor);
          if (_controller.text.trim().isNotEmpty) {
            _ejecutarBusqueda(nuevaBusqueda: false);
          }
        }
      },
    );
  }

  // ─── Shopping List Methods ─────────────────────────────────────

  void _agregarALista() {
    final item = _listaController.text.trim();
    if (item.isEmpty) return;
    setState(() {
      _listaCompras.add(item);
      _listaController.clear();
    });
  }

  void _quitarDeLista(int index) {
    setState(() {
      _listaCompras.removeAt(index);
    });
  }

  Future<void> _enviarListaIA() async {
    if (_listaCompras.isEmpty) return;

    setState(() {
      _procesandoLista = true;
      _respuestaLista = null;
    });

    final texto =
        'Tengo la siguiente lista de compras: ${_listaCompras.join(", ")}. '
        'Para cada producto de la lista, busca en las tiendas Éxito, Olímpica y Surtifamiliar '
        'y dime cuál es la opción más económica para cada uno. '
        'Luego dime cuál tienda tiene el total más bajo para toda la lista, '
        'y cuánto sería el total a pagar en esa tienda. '
        'Dame el desglose detallado producto por producto.';

    try {
      final data = await ChatApiService.preguntarIA(texto, []);

      if (data == null) {
        if (mounted) {
          setState(() {
            _respuestaLista =
                'Lo siento, no pude procesar tu lista. Intenta de nuevo.';
            _procesandoLista = false;
          });
        }
        return;
      }

      if (data['action'] == 'search') {
        await _procesarListaConIA(texto, data);
      } else {
        if (mounted) {
          setState(() {
            _respuestaLista = data['respuesta'] as String? ??
                'Listo, revisa los precios en los resultados de búsqueda.';
            _procesandoLista = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _respuestaLista =
              'Ocurrió un error al procesar tu lista. Intenta de nuevo.';
          _procesandoLista = false;
        });
      }
    }
  }

  Future<void> _procesarListaConIA(
    String texto,
    Map<String, dynamic> data,
  ) async {
    var query = data['query'] as String? ?? '';
    var toolCallId = data['toolCallId'] as String? ?? '';
    var arguments = data['arguments'] as String? ?? '';
    final historialBusquedas = <Map<String, dynamic>>[];

    while (true) {
      if (mounted) setState(() => _buscandoEnTiendas = true);

      final resultados = await MarketApiService.buscarEnTiendas(query);

      final resultadosMapeados = resultados
          .map((r) => {
                'nombre': r['nombre'],
                'tienda': r['tienda'],
                'precio': r['precio'],
                'link': r['link'],
              })
          .toList();

      if (mounted) setState(() => _buscandoEnTiendas = false);

      final response = await ChatApiService.reenviarConResultados(
        mensaje: texto,
        favoritos: [],
        resultadosBusqueda: resultadosMapeados,
        toolCallId: toolCallId,
        arguments: arguments,
        historialBusquedas: historialBusquedas,
      );

      if (response == null) {
        if (mounted) {
          setState(() {
            _respuestaLista =
                'Lo siento, no pude procesar tu lista. Intenta de nuevo.';
            _procesandoLista = false;
          });
        }
        return;
      }

      if (response['action'] != 'search') {
        final textoRespuesta = response['respuesta'] as String? ??
            'Listo, revisa los precios en los resultados de búsqueda.';
        if (mounted) {
          setState(() {
            _respuestaLista = textoRespuesta;
            _procesandoLista = false;
          });
        }
        return;
      }

      historialBusquedas.add({
        'toolCallId': toolCallId,
        'arguments': arguments,
        'resultadosBusqueda': resultadosMapeados,
      });

      query = response['query'] as String? ?? '';
      toolCallId = response['toolCallId'] as String? ?? '';
      arguments = response['arguments'] as String? ?? '';
    }
  }

  // ─── Shopping List UI ──────────────────────────────────────────

  Widget _buildListaCompras() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.shopping_basket_rounded,
              color: Color(0xFF1D9E75),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Crea tu lista de compras',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega productos uno a uno y encuentra el mejor precio',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _listaController,
                  decoration: InputDecoration(
                    hintText: 'Ej: arroz 1kg, huevos x30...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF1D9E75),
                        width: 2,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _agregarALista(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _agregarALista,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
          if (_listaCompras.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _listaCompras.asMap().entries.map((entry) {
                return Chip(
                  label: Text(entry.value),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _quitarDeLista(entry.key),
                  backgroundColor: const Color(0xFFE1F5EE),
                  deleteIconColor: const Color(0xFF0F6E56),
                  labelStyle: const TextStyle(color: Color(0xFF0F6E56)),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _procesandoLista ? null : _enviarListaIA,
                icon: _procesandoLista
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _procesandoLista
                      ? 'Procesando...'
                      : _buscandoEnTiendas
                          ? 'Buscando en tiendas...'
                          : 'Enviar lista a la IA',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF1D9E75).withOpacity(
                    0.6,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRespuestaLista() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: Color(0xFF1D9E75),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Resultado de tu lista',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: MarkdownBody(
              data: _respuestaLista ?? '',
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Color(0xFF2C2C2A), fontSize: 14),
                h3: const TextStyle(
                  color: Color(0xFF1D9E75),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTapLink: (text, href, title) {
                if (href != null) {
                  launchUrl(
                    Uri.parse(href),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_listaCompras.isNotEmpty) ...[
            const Text(
              'Productos consultados:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _listaCompras.map((item) {
                return Chip(
                  label: Text(item),
                  backgroundColor: const Color(0xFFE1F5EE),
                  labelStyle: const TextStyle(
                    color: Color(0xFF0F6E56),
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _respuestaLista = null;
                  _listaCompras.clear();
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Nueva lista'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1D9E75),
                side: const BorderSide(color: Color(0xFF1D9E75)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
