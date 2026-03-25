import 'package:flutter/material.dart';
import 'package:ecomerk2/data/services/user_api_service.dart';
import 'package:ecomerk2/data/services/market_api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _productoController = TextEditingController();
  List<String> _lista = [];
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
        setState(() {
          _userId = id;
          _lista = List<String>.from(usuario['alimentosFavoritos'] ?? []);
          _loading = false;
        });
      }
    }
  }

  Future<void> _agregarProducto() async {
    final nombre = _productoController.text.trim();
    if (nombre.isEmpty) return;

    final nuevaLista = [..._lista, nombre];
    setState(() => _lista = nuevaLista);
    _productoController.clear();

    if (_userId != null) {
      await ApiService.actualizarLista(_userId!, nuevaLista);
    }
  }

  Future<void> _eliminarProducto(int index) async {
    final nombre = _lista[index];
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

  Future<void> _compararPrecios(String producto) async {
    if (_buscandoPrecio[producto] == true) return;

    setState(() {
      _buscandoPrecio[producto] = true;
      _expandidos.add(producto);
    });

    try {
      final resultados = await MarketApiService.buscarEnTiendas(
        producto,
        orden: 'OrderByPriceASC',
      );
      if (mounted) {
        setState(() {
          _preciosPorProducto[producto] = resultados.take(4).toList();
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
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  // Busca todos los productos de la lista de una vez
  Future<void> _compararTodos() async {
    for (final producto in _lista) {
      if (_preciosPorProducto[producto] == null) {
        await _compararPrecios(producto);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mi lista de compras',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1D9E75),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_lista.isNotEmpty)
            TextButton.icon(
              onPressed: _compararTodos,
              icon: const Icon(Icons.compare_arrows, color: Colors.white, size: 18),
              label: const Text('Comparar todo',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1D9E75)))
          : Column(
              children: [
                // Resumen si hay items
                if (_lista.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D9E75).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF1D9E75).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_basket_outlined,
                            color: Color(0xFF1D9E75), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_lista.length} producto${_lista.length != 1 ? 's' : ''} en tu lista',
                          style: const TextStyle(
                              color: Color(0xFF1D9E75),
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                        const Spacer(),
                        const Text('Desliza para eliminar',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),

                // Campo para agregar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _productoController,
                          decoration: InputDecoration(
                            hintText: 'Agregar producto a tu lista...',
                            prefixIcon: const Icon(Icons.add_shopping_cart,
                                color: Color(0xFF1D9E75)),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          onSubmitted: (_) => _agregarProducto(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _agregarProducto,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D9E75),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 15),
                          elevation: 0,
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
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
                              Text('Tu lista está vacía',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF444441))),
                              SizedBox(height: 8),
                              Text('Agrega productos arriba para\ncomparar precios entre tiendas',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _lista.length,
                          itemBuilder: (context, index) {
                            final producto = _lista[index];
                            final precios = _preciosPorProducto[producto];
                            final buscando = _buscandoPrecio[producto] == true;
                            final expandido = _expandidos.contains(producto);

                            return Dismissible(
                              key: Key('$index-$producto'),
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
                                    Text('Eliminar',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 11)),
                                  ],
                                ),
                              ),
                              onDismissed: (_) => _eliminarProducto(index),
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
                                    )
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Fila principal del producto
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1D9E75)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                                Icons.shopping_cart_outlined,
                                                color: Color(0xFF1D9E75),
                                                size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  producto,
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF2C2C2A)),
                                                ),
                                                if (precios != null &&
                                                    precios.isNotEmpty)
                                                  Text(
                                                    'Desde \$${_formatearPrecio(precios[0]['precio'] as double)} · ${precios[0]['tienda']}',
                                                    style: const TextStyle(
                                                        color: Color(0xFF1D9E75),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          // Botones de acción
                                          if (!buscando) ...[
                                            // Botón comparar
                                            GestureDetector(
                                              onTap: () => precios != null
                                                  ? setState(() {
                                                      if (expandido) {
                                                        _expandidos.remove(producto);
                                                      } else {
                                                        _expandidos.add(producto);
                                                      }
                                                    })
                                                  : _compararPrecios(producto),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: precios != null
                                                      ? const Color(0xFF1D9E75)
                                                          .withOpacity(0.1)
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
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 20),
                                            onPressed: () =>
                                                _eliminarProducto(index),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Panel de comparación expandible
                                    if (expandido && precios != null)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FFFE),
                                          borderRadius: const BorderRadius.vertical(
                                              bottom: Radius.circular(16)),
                                          border: Border(
                                            top: BorderSide(
                                                color: Colors.grey.shade100),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(
                                                  14, 12, 14, 8),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.storefront,
                                                      size: 14,
                                                      color: Colors.grey),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Comparación de precios · ${precios.length} resultado${precios.length != 1 ? 's' : ''}',
                                                    style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500),
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
                                                        fontSize: 13)),
                                              )
                                            else
                                              ...precios
                                                  .asMap()
                                                  .entries
                                                  .map((entry) {
                                                final i = entry.key;
                                                final p = entry.value;
                                                final esMasBarato = i == 0;
                                                return GestureDetector(
                                                  onTap: () async {
                                                    final url = Uri.parse(
                                                        p['link'] ?? '');
                                                    try {
                                                      await launchUrl(url,
                                                          mode: LaunchMode
                                                              .externalApplication);
                                                    } catch (_) {}
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                        .fromLTRB(14, 0, 14, 8),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                      color: esMasBarato
                                                          ? const Color(
                                                                  0xFF1D9E75)
                                                              .withOpacity(0.08)
                                                          : Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      border: Border.all(
                                                        color: esMasBarato
                                                            ? const Color(
                                                                0xFF1D9E75)
                                                            : Colors.grey
                                                                .shade200,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        // Imagen del producto
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          child: Image.network(
                                                            p['imagen'] ?? '',
                                                            width: 48,
                                                            height: 48,
                                                            fit: BoxFit.contain,
                                                            errorBuilder: (_,
                                                                    __,
                                                                    ___) =>
                                                                Container(
                                                              width: 48,
                                                              height: 48,
                                                              color: Colors
                                                                  .grey[100],
                                                              child: const Icon(
                                                                  Icons
                                                                      .image_not_supported,
                                                                  color: Colors
                                                                      .grey,
                                                                  size: 20),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 10),
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
                                                                    fontSize: 12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              const SizedBox(
                                                                  height: 2),
                                                              Row(
                                                                children: [
                                                                  const Icon(
                                                                      Icons
                                                                          .store,
                                                                      size: 11,
                                                                      color: Colors
                                                                          .grey),
                                                                  const SizedBox(
                                                                      width: 3),
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
                                                                            FontWeight
                                                                                .bold,
                                                                        letterSpacing:
                                                                            0.5),
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
                                                                color: esMasBarato
                                                                    ? const Color(
                                                                        0xFF1D9E75)
                                                                    : const Color(
                                                                        0xFF2C2C2A),
                                                              ),
                                                            ),
                                                            if (esMasBarato)
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            2),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: const Color(
                                                                      0xFF1D9E75),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
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
                                                                              .bold),
                                                                ),
                                                              ),
                                                            const SizedBox(
                                                                height: 4),
                                                            const Row(
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .open_in_new,
                                                                    size: 10,
                                                                    color: Colors
                                                                        .grey),
                                                                SizedBox(
                                                                    width: 2),
                                                                Text(
                                                                    'Ver',
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .grey,
                                                                        fontSize:
                                                                            10)),
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
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}