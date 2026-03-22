import 'package:flutter/material.dart';
import 'package:ecomerk2/data/services/api_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String query = "";
  List<dynamic> resultados = [];
  bool cargando = false;

  Future<void> buscar(String texto) async {
    setState(() {
      query = texto;
      cargando = true;
    });

    try {
      // 🔥 AQUÍ debes conectar con tu API real
      final data = await ApiService.buscarProductos(texto);

      setState(() {
        resultados = data ?? [];
      });
    } catch (e) {
      print("Error en búsqueda: $e");
    }

    setState(() {
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buscar productos"),
        backgroundColor: const Color(0xFF1D9E75),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Buscar producto...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: buscar,
            ),
          ),

          if (cargando)
            const CircularProgressIndicator(),

          Expanded(
            child: ListView.builder(
              itemCount: resultados.length,
              itemBuilder: (context, index) {
                final item = resultados[index];

                return ListTile(
                  title: Text(item['nombre'] ?? 'Sin nombre'),
                  subtitle: Text("\$${item['precio'] ?? ''}"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}