import 'package:flutter/material.dart';
import 'package:ecomerk2/data/services/market_api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _todosResultados = [];
  List<dynamic> _resultadosFiltrados = [];
  bool _cargando = false;
  String _ordenSeleccionado = 'OrderByScoreDESC';
  String? _tiendaSeleccionada;

  Future<void> _ejecutarBusqueda() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      _cargando = true;
      _todosResultados = [];
      _resultadosFiltrados = [];
      _tiendaSeleccionada = null;
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
              content: Text('Error al conectar con los supermercados')),
        );
      }
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _aplicarFiltros() {
    List<dynamic> resultado = List.from(_todosResultados);

    if (_tiendaSeleccionada != null) {
      resultado = resultado
          .where((p) => p['tienda'] == _tiendaSeleccionada)
          .toList();
    }

    if (_ordenSeleccionado == 'OrderByPriceASC') {
      resultado.sort((a, b) => a['precio'].compareTo(b['precio']));
    }

    setState(() => _resultadosFiltrados = resultado);
  }

  String _formatearPrecio(double precio) {
    return precio
        .toStringAsFixed(0)
        .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  String _calcularAhorro(double precio) {
    if (_todosResultados.isEmpty) return '';
    final maxPrecio = _todosResultados
        .map((p) => p['precio'] as double)
        .reduce((a, b) => a > b ? a : b);
    if (maxPrecio == precio) return '';
    final ahorro = maxPrecio - precio;
    return 'Ahorras \$${_formatearPrecio(ahorro)}';
  }

  List<String> get _tiendas {
    return _todosResultados
        .map((p) => p['tienda'] as String)
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Buscar en Tuluá',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                          prefixIcon: const Icon(Icons.shopping_cart_outlined,
                              color: Color(0xFF1D9E75)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF1D9E75), width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _ejecutarBusqueda(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _cargando ? null : _ejecutarBusqueda,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D9E75),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
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
                      const Text('Ordenar: ',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      _buildFiltroChip('Relevancia', 'OrderByScoreDESC'),
                      const SizedBox(width: 8),
                      _buildFiltroChip('Más barato', 'OrderByPriceASC'),
                      if (_tiendas.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        const Text('Tienda: ',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ..._tiendas.map((tienda) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(tienda),
                                selected: _tiendaSeleccionada == tienda,
                                selectedColor:
                                    const Color(0xFF1D9E75).withOpacity(0.2),
                                checkmarkColor: const Color(0xFF1D9E75),
                                onSelected: (selected) {
                                  setState(() {
                                    _tiendaSeleccionada =
                                        selected ? tienda : null;
                                  });
                                  _aplicarFiltros();
                                },
                              ),
                            )),
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
                        fontWeight: FontWeight.w500),
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
                    Text('Buscando en supermercados...',
                        style: TextStyle(color: Colors.grey)),
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
                    Text('No encontramos productos',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    Text('Intenta con otro término de búsqueda',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

          // Estado inicial
          if (!_cargando && _controller.text.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🛒', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 16),
                    Text('Busca y compara precios',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    Text('Encuentra el mejor precio entre\nÉxito y Olímpica',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
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

                  return GestureDetector(
                    onTap: () async {
                      final url = Uri.parse(item['link'] ?? '');
                      try {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('No se pudo abrir el producto')),
                          );
                        }
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: esMasBarato
                            ? Border.all(
                                color: const Color(0xFF1D9E75), width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
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
                                  vertical: 6, horizontal: 12),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1D9E75),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(14)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_offer,
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    '¡Más barato! $ahorro',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
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
                                          color: Colors.grey),
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
                                            fontWeight: FontWeight.w600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      // Marca
                                      if (item['marca'] != null &&
                                          item['marca']
                                              .toString()
                                              .isNotEmpty)
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
                                          const Icon(Icons.store,
                                              size: 14, color: Colors.grey),
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
                                            const Icon(Icons.update,
                                                size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Act: ${item['fechaActualizacion']}',
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 4),
                                      // Ver en tienda
                                      Row(
                                        children: [
                                          const Icon(Icons.open_in_new,
                                              size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Ver en tienda',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11),
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
        setState(() => _ordenSeleccionado = valor);
        if (_todosResultados.isNotEmpty) _aplicarFiltros();
      },
    );
  }
}