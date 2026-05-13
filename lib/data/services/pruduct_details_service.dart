import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class ProductDetailsService {
  /// Método principal que decide a qué API consultar según la tienda
  static Future<Map<String, dynamic>?> consultarProductoPorId(
    String id,
    String tienda,
  ) async {
    switch (tienda.toLowerCase()) {
      case 'éxito':
        return await _getExitoById(id);
      case 'olímpica':
        return await _getOlimpicaById(id);
      case 'surtifamiliar':
        return await _getSurtifamiliarById(id);
      default:
        debugPrint("Tienda no soportada: $tienda");
        return null;
    }
  }

  // --- CONSULTA ÉXITO ---
  static Future<Map<String, dynamic>?> _getExitoById(String id) async {
    try {
      // VTEX permite filtrar directamente por productId usando fq=productId:
      final url = Uri.parse(
        'https://www.exito.com/api/catalog_system/pub/products/search?fq=productId:$id',
      );
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final product = data[0];
          final item = product['items'][0];
          return {
            'id': product['productId'],
            'nombre': product['productName'],
            'precio': (item['sellers'][0]['commertialOffer']['Price'] as num)
                .toDouble(),
            'tienda': 'Éxito',
            'imagen': item['images'][0]['imageUrl'],
            'link': 'https://www.exito.com/${product['linkText']}/p',
          };
        }
      }
    } catch (e) {
      debugPrint("Error consultando ID en Éxito: $e");
    }
    return null;
  }

  // --- CONSULTA OLÍMPICA ---
  static Future<Map<String, dynamic>?> _getOlimpicaById(String id) async {
    try {
      final url = Uri.parse(
        'https://www.olimpica.com/api/catalog_system/pub/products/search?fq=productId:$id',
      );
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final product = data[0];
          return {
            'id': product['productId'],
            'nombre': product['productName'],
            'precio':
                (product['items'][0]['sellers'][0]['commertialOffer']['Price']
                        as num)
                    .toDouble(),
            'tienda': 'Olímpica',
            'imagen': product['items'][0]['images'][0]['imageUrl'],
            'link': product['link'],
          };
        }
      }
    } catch (e) {
      debugPrint("Error consultando ID en Olímpica: $e");
    }
    return null;
  }

  // --- CONSULTA SURTIFAMILIAR ---
  static Future<Map<String, dynamic>?> _getSurtifamiliarById(
    String slug,
  ) async {
    try {
      // Construimos la URL con el slug como parámetro GET
      final url = Uri.parse(
        'https://ecommerce.surtifamiliar.com/backend/admin/frontend/web/index.php/item-info/ver-producto'
        '?id=&slug=$slug&userId=&cartId=undefined&getCloneAttributesInChildItem=1',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36',
          'Origin': 'https://www.surtifamiliar.com',
          'Referer': 'https://www.surtifamiliar.com/',
        },
      );

      if (response.statusCode == 200) {
        final item = jsonDecode(response.body);

        // Validamos que el objeto tenga datos (Surtifamiliar devuelve el objeto directo, no una lista)
        if (item != null && item['id'] != null) {
          // Construcción de la imagen basada en el JSON de detalle
          String imgUrl =
              "https://ecommerce.surtifamiliar.com/backend/admin/backend/web/archivosDelCliente/items/images/no-image.jpg";
          if (item['imagesDetail'] != null && item['imagesDetail'].isNotEmpty) {
            imgUrl =
                item['imagesDetail'][0]['path'] +
                item['imagesDetail'][0]['image'];
          }

          return {
            'id': item['id'].toString(),
            'nombre': item['name'],
            'precio': (item['currentPrice'] as num).toDouble(),
            'tienda': 'Surtifamiliar',
            'imagen': imgUrl,
            'link': 'https://www.surtifamiliar.com/producto/${item['slug']}',
            'marca':
                item['company'] ?? '', // Dato extra que viene en este endpoint
          };
        }
      }
    } catch (e) {
      debugPrint("Error en detalle Surtifamiliar: $e");
    }
    return null;
  }
}
