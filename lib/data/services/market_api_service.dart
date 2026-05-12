
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MarketApiService {
  // ═════════════════════════════════════════════════════════════════════
  // OBTENER PRODUCTO POR LINK (para enriquecer favoritos)
  // ═════════════════════════════════════════════════════════════════════

  /// Dado un [link] de producto guardado en favoritos, detecta la tienda
  /// por el dominio y consulta el API de esa tienda para extraer los datos
  /// reales: nombre, imagen, precio y tienda.
  ///
  /// Devuelve `null` si no se pudo obtener información.
  static Future<Map<String, dynamic>?> obtenerProductoPorLink(String link) async {
    try {
      final uri = Uri.parse(link);
      final host = uri.host.toLowerCase();

      if (host.contains('exito.com')) {
        return await _obtenerProductoExitoPorLink(uri);
      } else if (host.contains('olimpica.com')) {
        return await _obtenerProductoOlimpicaPorLink(uri);
      } else if (host.contains('surtifamiliar.com')) {
        return await _obtenerProductoSurtifamiliarPorLink(uri);
      }
    } catch (e) {
      debugPrint('[MarketApiService] obtenerProductoPorLink error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _obtenerProductoExitoPorLink(Uri uri) async {
    try {
      // El link tiene forma: https://www.exito.com/{linkText}/p
      final segments = uri.pathSegments.where((s) => s.isNotEmpty && s != 'p').toList();
      if (segments.isEmpty) return null;
      final linkText = segments.last;

      final apiUrl = Uri.parse(
        'https://www.exito.com/api/catalog_system/pub/products/search?fq=linkText:$linkText',
      );
      final response = await http.get(apiUrl, headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      });

      if (response.statusCode == 200 || response.statusCode == 206) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isEmpty) return null;
        final product = data[0];
        final item = product['items'][0];
        final seller = item['sellers'][0];
        final offer = seller['commertialOffer'];
        return {
          'nombre': product['productName'] ?? '',
          'precio': (offer['Price'] as num).toDouble(),
          'tienda': 'Éxito',
          'imagen': item['images'][0]['imageUrl'] ?? '',
          'link': uri.toString(),
        };
      }
    } catch (e) {
      debugPrint('[MarketApiService] Éxito por link error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _obtenerProductoOlimpicaPorLink(Uri uri) async {
    try {
      // El link tiene forma: https://www.olimpica.com/{linkText}/p o similar
      final segments = uri.pathSegments.where((s) => s.isNotEmpty && s != 'p').toList();
      if (segments.isEmpty) return null;
      final linkText = segments.last;

      final apiUrl = Uri.parse(
        'https://www.olimpica.com/api/catalog_system/pub/products/search?fq=linkText:$linkText',
      );
      final response = await http.get(apiUrl, headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      });

      if (response.statusCode == 200 || response.statusCode == 206) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isEmpty) return null;
        final product = data[0];
        final item = product['items'][0];
        final seller = item['sellers'][0];
        final offer = seller['commertialOffer'];
        return {
          'nombre': product['productName'] ?? '',
          'precio': (offer['Price'] as num).toDouble(),
          'tienda': 'Olímpica',
          'imagen': item['images'][0]['imageUrl'] ?? '',
          'link': uri.toString(),
        };
      }
    } catch (e) {
      debugPrint('[MarketApiService] Olímpica por link error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _obtenerProductoSurtifamiliarPorLink(Uri uri) async {
    try {
      // El link tiene forma: https://www.surtifamiliar.com/producto/{slug}
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return null;
      final slug = segments.last;

      final apiUrl = Uri.parse(
        'https://ecommerce.surtifamiliar.com/backend/admin/frontend/web/index.php/categoria-info/show-items-by-cattegory',
      );
      final response = await http.post(apiUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          body: jsonEncode({
            'id': null,
            'slug': '',
            'pageSize': 1,
            'searchText': slug.replaceAll('-', ' '),
            'internSearchText': '',
            'cartId': 'undefined',
            'userId': '',
            'slugPromition': null,
            'filters': {
              'pageNumber': 1,
              'attributes': [],
              'productHighPrice': 0,
              'productLowPrice': 0,
              'sort': '1',
            },
            'typeProducts': null,
          }));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        // Buscar el item que coincida con el slug
        final item = items.firstWhere(
          (i) => (i['slug'] ?? '').toString() == slug,
          orElse: () => items.isNotEmpty ? items[0] : null,
        );
        if (item == null) return null;
        const baseImgUrl =
            'https://ecommerce.surtifamiliar.com/backend/admin/backend/web/archivosDelCliente/items/images/';
        return {
          'nombre': item['name'] ?? '',
          'precio': (item['currentPrice'] as num?)?.toDouble() ?? 0.0,
          'tienda': 'Surtifamiliar',
          'imagen': baseImgUrl + (item['principalImage'] ?? ''),
          'link': uri.toString(),
        };
      }
    } catch (e) {
      debugPrint('[MarketApiService] Surtifamiliar por link error: $e');
    }
    return null;
  }

  // ═════════════════════════════════════════════════════════════════════
  // BUSCAR EN TIENDAS (búsqueda por texto)
  // ═════════════════════════════════════════════════════════════════════

  static Future<List<dynamic>> buscarEnTiendas(
    String query, {
    String orden = 'OrderByScoreDESC',
  }) async {
    List<dynamic> todosLosResultados = [];

    try {
      final resultados = await Future.wait([
        _buscarEnExito(query, orden: orden),
        _buscarEnOlimpica(query, orden: orden),
        _buscarEnSurtifamiliar(query, orden: orden),
      ]);

      for (var lista in resultados) {
        todosLosResultados.addAll(lista);
      }

      todosLosResultados.removeWhere((p) => p['precio'] == null || (p['precio'] as num) <= 0);
      todosLosResultados.sort((a, b) => a['precio'].compareTo(b['precio']));
    } catch (e) {
      debugPrint("Error en MarketApiService: $e");
    }
    return todosLosResultados;
  }

  static Future<List<dynamic>> _buscarEnExito(
    String query, {
    String orden = 'OrderByScoreDESC',
  }) async {
    try {
      final String queryEncoded = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://www.exito.com/api/catalog_system/pub/products/search?ft=$queryEncoded&O=$orden&_from=0&_to=9',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      debugPrint("Status Éxito: ${response.statusCode}");

      // Aceptamos 200 y 206 (Contenido parcial, común en VTEX)
      if (response.statusCode == 200 || response.statusCode == 206) {
        final List<dynamic> data = jsonDecode(response.body);

        if (data.isEmpty) return [];

        // Usamos map y convertimos a lista, filtrando nulos
        return data
            .map((product) {
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
            })
            .where((element) => element != null)
            .toList();
      }
    } catch (e) {
      debugPrint("Error en el método _buscarEnExito: $e");
    }
    return [];
  }

  static Future<List<dynamic>> _buscarEnOlimpica(
    String query, {
    String orden = 'OrderByScoreDESC',
  }) async {
    try {
      final String queryEncoded = Uri.encodeComponent(query);

      final url = Uri.parse(
        'https://www.olimpica.com/api/catalog_system/pub/products/search/$queryEncoded?O=$orden&_from=0&_to=9',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
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
          } catch (e) {
            continue;
          }
        }
        return resultados;
      }
    } catch (e) {
      debugPrint("Error Olímpica Sort: $e");
    }
    return [];
  }

  static Future<List<dynamic>> _buscarEnSurtifamiliar(
    String query, {
    String orden = 'OrderByScoreDESC',
  }) async {
    try {
      final url = Uri.parse(
        'https://ecommerce.surtifamiliar.com/backend/admin/frontend/web/index.php/categoria-info/show-items-by-cattegory',
      );

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
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
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
            "sort": surtiSort,
          },
          "typeProducts": null,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        List<dynamic> resultados = [];
        const String baseImgUrl =
            "https://ecommerce.surtifamiliar.com/backend/admin/backend/web/archivosDelCliente/items/images/";

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
        debugPrint(
          "EcoMerca2 -> Surtifamiliar ($surtiSort): ${resultados.length} items.",
        );
        return resultados;
      }
    } catch (e) {
      debugPrint("Error en Surtifamiliar Sort: $e");
    }
    return [];
  }
}
