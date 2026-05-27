import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/env_config.dart';

class MarketApiService {
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

      todosLosResultados.removeWhere(
        (p) => p['precio'] == null || (p['precio'] as num) <= 0,
      );
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
        '${EnvConfig.exitoApiUrl}?ft=$queryEncoded&O=$orden&_from=0&_to=9',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': EnvConfig.userAgentExito,
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
                  'id': product['productId'],
                  'nombre': product['productName'] ?? 'Producto Éxito',
                  'precio': (offer['Price'] as num).toDouble(),
                  'tienda': 'Éxito',
                  'imagen': item['images'][0]['imageUrl'] ?? '',
                  'link': '${EnvConfig.exitoWebUrl}/${product['linkText']}/p',
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
        '${EnvConfig.olimpicaApiUrl}/$queryEncoded?O=$orden&_from=0&_to=9',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': EnvConfig.userAgentOlimpica,
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
                'id': item['productId'],
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
      final url = Uri.parse(EnvConfig.surtifamiliarApiSearchUrl);

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
          'Origin': EnvConfig.surtifamiliarWebUrl,
          'Referer': '${EnvConfig.surtifamiliarWebUrl}/',
          'User-Agent': EnvConfig.userAgentSurtifamiliar,
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
        final String baseImgUrl = EnvConfig.surtifamiliarImagesUrl;

        for (var item in items) {
          double precio = (item['currentPrice'] as num?)?.toDouble() ?? 0.0;

          String categoriaSlug = item['categoria_slug'] ?? '';
          String productoSlug = item['producto_slug'] ?? '';

          String slugCrudo = item['slug'] ?? '';
          String productId = slugCrudo.contains('/')
              ? slugCrudo.split('/').last
              : slugCrudo;

          String linkCompleto = "${EnvConfig.surtifamiliarWebUrl}/";
          if (categoriaSlug.isNotEmpty && productoSlug.isNotEmpty) {
            linkCompleto = "$linkCompleto$categoriaSlug/$productoSlug";
          } else if (slugCrudo.isNotEmpty) {
            // Aseguramos el '/' intermedio para que el enlace de respaldo no se rompa
            linkCompleto = "$linkCompleto$slugCrudo";
          }

          if (precio > 0) {
            resultados.add({
              'id': productId,
              'nombre': item['name'] ?? 'Producto Surtifamiliar',
              'precio': precio,
              'tienda': 'Surtifamiliar',
              'imagen': baseImgUrl + (item['principalImage'] ?? ''),
              'link': linkCompleto,
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
