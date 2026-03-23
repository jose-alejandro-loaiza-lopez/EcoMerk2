import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class MarketApiService {
  static Future<List<dynamic>> buscarEnTiendas(String query, {String orden = 'OrderByScoreDESC'}) async {
    List<dynamic> todosLosResultados = [];

    try {
      final resultados = await Future.wait([
        _buscarEnExito(query, orden: orden),
        _buscarEnOlimpica(query),
      ]);

      for (var lista in resultados) {
        todosLosResultados.addAll(lista);
      }

      todosLosResultados.sort((a, b) => a['precio'].compareTo(b['precio']));

    } catch (e) {
      debugPrint("Error en MarketApiService: $e");
    }
    return todosLosResultados;
  }

  static Future<List<dynamic>> _buscarEnExito(String query, {String orden = 'OrderByScoreDESC'}) async {
    try {
      final String queryEncoded = Uri.encodeComponent(query);
      final url = Uri.parse('https://www.exito.com/api/catalog_system/pub/products/search?ft=$queryEncoded&O=$orden');

      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      });

      debugPrint("Status Éxito: ${response.statusCode}");

      // Aceptamos 200 y 206 (Contenido parcial, común en VTEX)
      if (response.statusCode == 200 || response.statusCode == 206) {
        final List<dynamic> data = jsonDecode(response.body);

        if (data.isEmpty) return [];

        // Usamos map y convertimos a lista, filtrando nulos
        return data.map((product) {
          try {
            final item = product['items'][0];
            final seller = item['sellers'][0];
            final offer = seller['commertialOffer'];

            return {
              'nombre': product['productName'] ?? 'Sin nombre',
              'precio': (offer['Price'] as num).toDouble(),
              'tienda': 'Éxito',
              'imagen': item['images'][0]['imageUrl'] ?? '',
              'link': 'https://www.exito.com/${product['linkText']}/p',
              'marca': product['brand'] ?? '',
            };
          } catch (e) {
            return null;
          }
        }).where((element) => element != null).toList();
      }
    } catch (e) {
      debugPrint("Error en el método _buscarEnExito: $e");
    }
    return [];
  }

  static Future<List<dynamic>> _buscarEnOlimpica(String query, {String orden = 'OrderByScoreDESC'}) async {
    try {
      final String queryEncoded = Uri.encodeComponent(query);

      final url = Uri.parse(
          'https://www.olimpica.com/api/catalog_system/pub/products/search/$queryEncoded?O=$orden'
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 206) {
        final List<dynamic> data = jsonDecode(response.body);
        List<dynamic> resultados = [];

        for (var item in data) {
          try {
            final firstItem = item['items'][0];
            final seller = firstItem['sellers'][0];
            final offer = seller['commertialOffer'];

            double precio = (offer['Price'] as num).toDouble();

            if (precio > 0) {
              resultados.add({
                'nombre': item['productName'] ?? 'Producto Olímpica',
                'precio': precio,
                'tienda': 'Olímpica',
                'imagen': firstItem['images'][0]['imageUrl'] ?? '',
                'link': item['link'] ?? '',
                'marca': item['brand'] ?? 'Olímpica',
              });
            }
          } catch (e) { continue; }
        }
        return resultados;
      }
    } catch (e) {
      debugPrint("Error Olímpica Sort: $e");
    }
    return [];
  }

}