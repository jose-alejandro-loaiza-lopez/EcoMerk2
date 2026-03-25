import 'package:get/get.dart';
import 'package:ecomerk2/data/services/user_api_service.dart';

class FavoritesController extends GetxController {
  var favorites = <Map<String, dynamic>>[].obs;

  void addFavorite(Map<String, dynamic> item) {
    if (!isFavorite(item)) {
      final formattedItem = {
        "nombre": item['nombre'],
        "precio": "\$${(item['precio'] as num).toDouble().toStringAsFixed(0)}",
        "tienda": item['tienda'],
        "imagen": item['imagen'],
        "link": item['link'],
      };

      favorites.add(formattedItem);
      guardarEnBackend();
    }
  }

  void removeFavorite(Map<String, dynamic> item) {
    favorites.removeWhere((fav) => fav['link'] == item['link']);
    guardarEnBackend(); // 🔥 importante actualizar también al eliminar
  }

  bool isFavorite(Map<String, dynamic> item) {
    return favorites.any((fav) => fav['link'] == item['link']);
  }

  Future<void> guardarEnBackend() async {
    final userId = await ApiService.obtenerUserId();
    if (userId != null) {
      // 🔥 Convertimos a List<String> (solo links)
      final listaLinks = favorites.map((fav) => fav['link'] as String).toList();

      try {
        await ApiService.actualizarLista(userId, listaLinks);
      } catch (e) {
        print("Error guardando favoritos: $e");
      }
    }
  }
}