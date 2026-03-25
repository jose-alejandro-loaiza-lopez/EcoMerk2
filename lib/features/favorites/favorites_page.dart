import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'favorites_controller.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key}); // Agregado el const del segundo ejemplo

  @override
  Widget build(BuildContext context) {
    // Buscamos el controlador dentro del build para mantener la clase limpia
    final FavoritesController favController = Get.find();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Favoritos"), // Título combinado
        backgroundColor: const Color(0xFF1D9E75),
      ),
      body: Obx(() {
        if (favController.favorites.isEmpty) {
          return const Center(
            child: Text(
              "No tienes favoritos aún ❤️",
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: favController.favorites.length,
          itemBuilder: (context, index) {
            final item = favController.favorites[index];

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                leading: Image.network(
                  item['imagen'],
                  width: 50,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image),
                ),
                title: Text(item['nombre']),
                subtitle: Text("\$${item['precio']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    favController.removeFavorite(item);
                  },
                ),
              ),
            );
          },
        );
      }),
    );
  }
}