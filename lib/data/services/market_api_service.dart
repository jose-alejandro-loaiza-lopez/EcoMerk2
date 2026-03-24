import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class MarketApiService {
  static Future<List<dynamic>> buscarEnTiendas(String query, {String orden = 'OrderByScoreDESC'}) async {
    List<dynamic> todosLosResultados = [];

    try {
      final resultados = await Future.wait([
        _buscarEnExito(query, orden: orden),
        _buscarEnOlimpica(query),
        _buscarEnSurtifamiliar(query),
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
      final url = Uri.parse('https://www.exito.com/api/catalog_system/pub/products/search?ft=$queryEncoded&O=$orden&_from=0&_to=9');

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
          'https://www.olimpica.com/api/catalog_system/pub/products/search/$queryEncoded?O=$orden&_from=0&_to=9'
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

  static Future<List<dynamic>> _buscarEnSurtifamiliar(String query, {String orden = 'OrderByScoreDESC'}) async {
    try {
      final url = Uri.parse('https://ecommerce.surtifamiliar.com/backend/admin/frontend/web/index.php/categoria-info/show-items-by-cattegory');

      String surtiSort = "1";
      if (orden == 'OrderByPriceASC') {
        surtiSort = "4";
      } else if (orden == 'OrderByScoreDESC') {
        surtiSort = "1";
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/plain, */*',
          'Origin': 'https://www.surtifamiliar.com',
          'Referer': 'https://www.surtifamiliar.com/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
        },
        body: jsonEncode({
          "id": null,
          "slug": "",
          "pageSize": 10,
          "searchText": query,
          "internSearchText": "",
          "cartId": "undefined",
          "userId": "",
          "slugPromition": null,
          "filters": {
            "pageNumber": 1,
            "attributes": [],
            "productHighPrice": 0,
            "productLowPrice": 0,
            "sort": surtiSort
          },
          "typeProducts": null
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        List<dynamic> resultados = [];
        const String baseImgUrl = "https://ecommerce.surtifamiliar.com/backend/admin/backend/web/archivosDelCliente/items/images/";

        for (var item in items) {
          double precio = (item['currentPrice'] as num?)?.toDouble() ?? 0.0;

          if (precio > 0) {
            resultados.add({
              'nombre': item['name'] ?? 'Producto Surtifamiliar',
              'precio': precio,
              'tienda': 'Surtifamiliar',
              'imagen': baseImgUrl + (item['principalImage'] ?? ''),
              'link': 'https://www.surtifamiliar.com/producto/${item['slug']}',
            });
          }
        }
        debugPrint("EcoMerca2 -> Surtifamiliar ($surtiSort): ${resultados.length} items.");
        return resultados;
      }
    } catch (e) {
      debugPrint("Error en Surtifamiliar Sort: $e");
    }
    return [];
  }

}