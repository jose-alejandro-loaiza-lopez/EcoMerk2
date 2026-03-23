import 'package:flutter/material.dart';
import 'package:ecomerk2/data/services/market_api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // 1. Agregamos el controlador para el texto
  final TextEditingController _controller = TextEditingController();
  List<dynamic> resultados = [];
  bool cargando = false;
  String ordenSeleccionado = 'OrderByScoreDESC';

  // 2. Función de búsqueda corregida
  Future<void> ejecutarBusqueda() async {
    String texto = _controller.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      cargando = true;
      resultados = [];
    });

    try {
      final data = await MarketApiService.buscarEnTiendas(
          texto,
          orden: ordenSeleccionado
      );

      setState(() {
        resultados = data;
      });
    } catch (e) {
      debugPrint("Error en búsqueda: $e");
      if (mounted) { // Verificamos que el usuario siga en la pantalla
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al conectar con los supermercados")),
        );
      }
    } finally {
      setState(() {
        cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buscar en Tuluá"),
        backgroundColor: const Color(0xFF1D9E75),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column( // 1. Cambiamos a Column para apilar verticalmente
              children: [
                // --- FILA 1: BUSCADOR ---
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: "Ej: Arroz, Café...",
                          prefixIcon: const Icon(Icons.shopping_cart),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onSubmitted: (_) => ejecutarBusqueda(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: cargando ? null : ejecutarBusqueda,
                      icon: const Icon(Icons.search),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF1D9E75),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10), // Espacio entre buscador y filtros

                // --- FILA 2: FILTROS ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    FilterChip(
                      label: const Text("Relevancia"),
                      selected: ordenSeleccionado == 'OrderByScoreDESC',
                      selectedColor: const Color(0xFF1D9E75).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF1D9E75),
                      onSelected: (bool selected) {
                        setState(() => ordenSeleccionado = 'OrderByScoreDESC');
                        ejecutarBusqueda();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text("Más barato"),
                      selected: ordenSeleccionado == 'OrderByPriceASC',
                      selectedColor: const Color(0xFF1D9E75).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF1D9E75),
                      onSelected: (bool selected) {
                        setState(() => ordenSeleccionado = 'OrderByPriceASC');
                        ejecutarBusqueda();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Indicador de carga
          if (cargando)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
            ),

          // Lista de resultados
          Expanded(
            child: ListView.builder(
              itemCount: resultados.length,
              itemBuilder: (context, index) {
                if (index >= resultados.length) return const SizedBox.shrink();
                final item = resultados[index];

                return GestureDetector(
                  onTap: () async {
                    final String urlString = item['link'] ?? '';
                    if (urlString.isEmpty) return;

                    final Uri url = Uri.parse(urlString);

                    try {
                      // Intentamos abrirlo de forma externa (en el navegador del cel)
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      debugPrint("No se pudo abrir el link: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("No se pudo abrir la página del producto")),
                      );
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Imagen Grande
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                          child: Image.network(
                            item['imagen'],
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.contain, // Mantiene la proporción sin recortar
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported, size: 50),
                            ),
                          ),
                        ),

                        // 2. Información del producto
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nombre del Producto
                              Text(
                                item['nombre'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),

                              // Precio resaltado
                              Text(
                                "\$${item['precio'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Color(0xFF1D9E75),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),

                              const SizedBox(height: 4),

                              // Cadena de Supermercado (Badge)
                              Row(
                                children: [
                                  const Icon(Icons.store, size: 16, color: Colors.grey),
                                  const SizedBox(width: 5),
                                  Text(
                                    item['tienda'].toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      letterSpacing: 1.1,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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
}