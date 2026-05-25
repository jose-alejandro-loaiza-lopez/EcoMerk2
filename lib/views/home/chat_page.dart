import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ecomerk2/data/services/navigation_mode_service.dart';
import 'package:ecomerk2/data/services/chat_api_service.dart';
import 'package:ecomerk2/data/services/user_api_service.dart';
import 'package:ecomerk2/data/services/pruduct_details_service.dart';
import 'package:ecomerk2/data/services/market_api_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  /// Permite que una nueva instancia sepa si hay una IA procesando en
  /// background y espere a que termine para mostrar la respuesta.
  static Completer<void>? _completerProcesamiento;

  static Future<void>? get procesamientoPendiente =>
      _completerProcesamiento?.future;

  static void _iniciarProcesamiento() {
    _completerProcesamiento = Completer<void>();
  }

  static void _completarProcesamiento() {
    _completerProcesamiento?.complete();
    _completerProcesamiento = null;
  }

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<Map<String, dynamic>> _mensajes = [];
  final List<Map<String, dynamic>> _favoritos = [];
  bool _cargando = false;
  bool _buscandoEnTiendas = false;
  bool _cargandoHistorial = true;
  bool _hayMas = false;
  bool _cargandoMas = false;
  int? _cursorAntes;
  bool _mostrarMenuRapido = true;

  // Animación para "Escribiendo..."
  late AnimationController _dotController;

  final List<Map<String, dynamic>> _menuRapido = [
    {
      'icono': Icons.restaurant_menu_rounded,
      'titulo': 'Recetas',
      'subtitulo': 'Ideas para cocinar',
      'mensaje': '¿Qué puedo cocinar con arroz y pollo?',
      'color': const Color(0xFFE8F5E9),
      'colorIcon': const Color(0xFF388E3C),
    },
    {
      'icono': Icons.savings_rounded,
      'titulo': 'Ahorrar',
      'subtitulo': 'Consejos de ahorro',
      'mensaje': '¿Cómo ahorro en mi mercado semanal?',
      'color': const Color(0xFFE3F2FD),
      'colorIcon': const Color(0xFF1976D2),
    },
    {
      'icono': Icons.compare_arrows_rounded,
      'titulo': 'Comparar',
      'subtitulo': 'Precios entre tiendas',
      'mensaje':
          '¿Qué productos están más baratos entre Éxito, Olímpica y Surtifamiliar?',
      'color': const Color(0xFFFFF8E1),
      'colorIcon': const Color(0xFFF9A825),
    },
    {
      'icono': Icons.shopping_basket_rounded,
      'titulo': 'Mercado',
      'subtitulo': 'Lista económica',
      'mensaje': 'Dame una receta económica para 4 personas',
      'color': const Color(0xFFF3E5F5),
      'colorIcon': const Color(0xFF7B1FA2),
    },
  ];

  final List<String> _sugerenciasRapidas = [
    '¿Precios del arroz?',
    'Consulta carnes',
    '¿Precios del aceite?',
    'Receta económica',
    '¿Cómo ahorrar?',
  ];

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _cargarHistorial();
    _cargarFavoritos();
    _esperarProcesamientoPendiente();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _dotController.dispose();
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    setState(() => _cargandoHistorial = true);
    final data = await ChatApiService.obtenerMensajes();

    if (data != null && mounted) {
      final mensajes = List<Map<String, dynamic>>.from(data['mensajes'] ?? []);

      setState(() {
        _mensajes.clear();
        for (final m in mensajes) {
          _mensajes.add({
            'id': m['id'],
            'rol': m['esIa'] == true ? 'ia' : 'usuario',
            'texto': m['contenido'],
          });
        }
        _hayMas = data['hayMas'] == true;
        if (mensajes.isNotEmpty) {
          _cursorAntes = mensajes.last['id'];
        }
        _cargandoHistorial = false;
        if (_mensajes.isNotEmpty) _mostrarMenuRapido = false;
      });
    } else {
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  Future<void> _cargarFavoritos() async {
    final userId = await ApiService.obtenerUserId();
    if (userId == null) return;
    final usuario = await ApiService.obtenerUsuario(userId);
    if (usuario == null || usuario['_tokenExpirado'] == true) return;
    final raw = List<dynamic>.from(
      usuario['favoritos'] ?? usuario['alimentosFavoritos'] ?? [],
    );

    final List<Map<String, dynamic>> enriquecidos = [];
    for (final item in raw) {
      if (item is! Map) {
        enriquecidos.add({'nombre': item.toString()});
        continue;
      }

      final rawProductId = (item['productId'] ?? '').toString();
      if (rawProductId.isEmpty) {
        enriquecidos.add(Map<String, dynamic>.from(item));
        continue;
      }

      String tienda = '';
      String productId = rawProductId;
      if (rawProductId.contains('::')) {
        final parts = rawProductId.split('::');
        tienda = parts[0];
        productId = parts.sublist(1).join('::');
      }

      if (productId.isEmpty || tienda.isEmpty) {
        enriquecidos.add(Map<String, dynamic>.from(item));
        continue;
      }

      try {
        final detalles = await ProductDetailsService.consultarProductoPorId(
          productId,
          tienda,
        );

        if (detalles != null) {
          enriquecidos.add({
            ...Map<String, dynamic>.from(item),
            'nombre': detalles['nombre'] ?? item['nombre'],
            'precio': '\$${_formatearPrecio(detalles['precio'] as double)}',
            'imagen': detalles['imagen'] ?? item['imagen'],
            'link': detalles['link'] ?? item['link'],
            'tienda': detalles['tienda'] ?? tienda,
            'productId': rawProductId,
          });
        } else {
          enriquecidos.add(Map<String, dynamic>.from(item));
        }
      } catch (e) {
        enriquecidos.add(Map<String, dynamic>.from(item));
      }
    }

    if (mounted) {
      setState(() {
        _favoritos.addAll(enriquecidos);
      });
    }
  }

  String _formatearPrecio(double precio) {
    return precio
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  Future<void> _cargarMas() async {
    if (!_hayMas || _cursorAntes == null) return;
    final data = await ChatApiService.obtenerMensajes(antes: _cursorAntes);
    if (data != null && mounted) {
      final mensajes = List<Map<String, dynamic>>.from(data['mensajes'] ?? []);

      setState(() {
        for (final m in mensajes.reversed) {
          _mensajes.add({
            'id': m['id'],
            'rol': m['esIa'] == true ? 'ia' : 'usuario',
            'texto': m['contenido'],
          });
        }
        _hayMas = data['hayMas'] == true;
        if (mensajes.isNotEmpty) {
          _cursorAntes = mensajes.last['id'];
        }
      });
    }
    _cargandoMas = false;
  }

  void _onScroll() {
    if (!_hayMas || _cargandoMas || !_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _cargandoMas = true;
      _cargarMas();
    }
  }

  Future<void> _enviarMensaje(String texto) async {
    if (texto.trim().isEmpty || _cargando) return;
    _controller.clear();
    _focusNode.unfocus();

    setState(() {
      _mensajes.insert(0, {'rol': 'usuario', 'texto': texto});
      _cargando = true;
      _mostrarMenuRapido = false;
    });

    ChatPage._iniciarProcesamiento();
    _procesarRespuestaIA(texto);
  }

  Future<void> _procesarRespuestaIA(String texto) async {
    try {
      // FASE 1: enviar mensaje a la IA
      final data = await ChatApiService.preguntarIA(texto, _favoritos);

      if (data == null) {
        if (mounted) {
          setState(() {
            _mensajes.insert(0, {
              'rol': 'ia',
              'texto':
                  'Lo siento, no pude procesar tu consulta. Intenta de nuevo.',
            });
            _cargando = false;
          });
        }
        return;
      }

      if (data['action'] == 'search') {
        // La IA quiere buscar en tiendas → loop para llamadas secuenciales
        var query = data['query'] as String? ?? '';
        var toolCallId = data['toolCallId'] as String? ?? '';
        var arguments = data['arguments'] as String? ?? '';

        while (true) {
          if (mounted) setState(() => _buscandoEnTiendas = true);

          final resultados = await MarketApiService.buscarEnTiendas(query);

          final resultadosMapeados = resultados
              .map(
                (r) => {
                  'nombre': r['nombre'],
                  'tienda': r['tienda'],
                  'precio': r['precio'],
                  'link': r['link'],
                },
              )
              .toList();

          if (mounted) setState(() => _buscandoEnTiendas = false);

          final response = await ChatApiService.reenviarConResultados(
            mensaje: texto,
            favoritos: _favoritos,
            resultadosBusqueda: resultadosMapeados,
            toolCallId: toolCallId,
            arguments: arguments,
          );

          if (response == null || response['action'] != 'search') {
            final textoRespuesta =
                response?['respuesta'] as String? ??
                'Lo siento, no pude procesar tu consulta. Intenta de nuevo.';

            if (mounted) {
              setState(() {
                _mensajes.insert(0, {'rol': 'ia', 'texto': textoRespuesta});
                _cargando = false;
              });
            }
            return;
          }

          // La IA pide otra búsqueda: continuar el loop
          query = response['query'] as String? ?? '';
          toolCallId = response['toolCallId'] as String? ?? '';
          arguments = response['arguments'] as String? ?? '';
        }
      } else {
        // Respuesta normal de la IA
        final textoRespuesta =
            data['respuesta'] as String? ??
            'Lo siento, no pude procesar tu consulta. Intenta de nuevo.';

        if (mounted) {
          setState(() {
            _mensajes.insert(0, {'rol': 'ia', 'texto': textoRespuesta});
            _cargando = false;
          });
        }
      }
    } finally {
      ChatPage._completarProcesamiento();
    }
  }

  /// Si hay una IA procesando en background desde una instancia anterior
  /// (ej. el usuario salió y volvió), espera a que termine y recarga.
  Future<void> _esperarProcesamientoPendiente() async {
    final pendiente = ChatPage.procesamientoPendiente;
    if (pendiente == null) return;
    if (mounted) setState(() => _cargando = true);
    await pendiente;
    if (mounted) {
      setState(() => _cargando = false);
      await _cargarHistorial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usarMenuLateral = NavigationModeService.instance.isDrawerMode;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        leading: usarMenuLateral
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.go('/home'),
              )
            : null,
        backgroundColor: const Color(0xFF1D9E75),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF0F6E56),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Asistente IA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _buscandoEnTiendas
                      ? 'Buscando en tiendas...'
                      : _cargando
                      ? 'Escribiendo...'
                      : 'EcoMerk2',
                  style: TextStyle(
                    color: _buscandoEnTiendas || _cargando
                        ? const Color(0xFFFFE082)
                        : const Color(0xFF9FE1CB),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () =>
                setState(() => _mostrarMenuRapido = !_mostrarMenuRapido),
            icon: Icon(
              _mostrarMenuRapido ? Icons.grid_off : Icons.grid_view_rounded,
              color: Colors.white,
            ),
            tooltip: 'Menú rápido',
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Banner cargando historial
          if (_cargandoHistorial)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFE1F5EE),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1D9E75),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Cargando historial...',
                    style: TextStyle(color: Color(0xFF0F6E56), fontSize: 12),
                  ),
                ],
              ),
            ),

          // Banner "Buscando en tiendas..." (FASE 2)
          if (_buscandoEnTiendas)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFE3F2FD),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Buscando en tiendas...',
                    style: TextStyle(color: Color(0xFF1976D2), fontSize: 12),
                  ),
                ],
              ),
            ),

          // Banner "Escribiendo..." visible
          if (_cargando)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFFF8E1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _dotController,
                    builder: (context, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final delay = i / 3;
                          final value = (_dotController.value - delay).clamp(
                            0.0,
                            1.0,
                          );
                          return Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                const Color(0xFFFFCC02),
                                const Color(0xFFF9A825),
                                value,
                              ),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'El asistente está escribiendo...',
                    style: TextStyle(
                      color: Color(0xFFF57F17),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Contenido principal
          Expanded(
            child: _cargandoHistorial
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
                  )
                : _mostrarMenuRapido
                ? _buildMenuInicial()
                : _mensajes.isEmpty
                ? _buildEstadoInicial()
                : ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _mensajes.length + (_cargando ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_cargando && index == 0) {
                        return _buildBurbujaCargando();
                      }
                      return _buildBurbuja(
                        _mensajes[index - (_cargando ? 1 : 0)],
                      );
                    },
                  ),
          ),

          // Sugerencias rápidas encima del input
          if (!_cargando && _mensajes.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _sugerenciasRapidas.map((s) {
                    return GestureDetector(
                      onTap: () => _enviarMensaje(s),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1F5EE),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF1D9E75).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            color: Color(0xFF0F6E56),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Input
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    // Campo bloqueado mientras carga
                    enabled: !_cargando,
                    decoration: InputDecoration(
                      hintText: _cargando
                          ? 'Espera la respuesta...'
                          : 'Pregúntame sobre recetas o precios...',
                      hintStyle: TextStyle(
                        color: _cargando
                            ? Colors.orange[200]
                            : Colors.grey[400],
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: _cargando
                          ? const Color(0xFFFFF8E1)
                          : const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _cargando ? null : _enviarMensaje,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _cargando
                      ? null
                      : () => _enviarMensaje(_controller.text),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _cargando
                          ? Colors.grey[300]
                          : const Color(0xFF1D9E75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _cargando
                          ? Icons.hourglass_top_rounded
                          : Icons.send_rounded,
                      color: _cargando ? Colors.grey : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Menú inicial con tarjetas interactivas
  Widget _buildMenuInicial() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF1D9E75),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '¿En qué te ayudo hoy?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C2C2A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Comparo precios entre Éxito, Olímpica y Surtifamiliar',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Tarjetas de menú 2x2
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: _menuRapido.map((item) {
              return GestureDetector(
                onTap: () => _enviarMensaje(item['mensaje']),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: item['color'] as Color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (item['colorIcon'] as Color).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        item['icono'] as IconData,
                        color: item['colorIcon'] as Color,
                        size: 26,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['titulo'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: item['colorIcon'] as Color,
                            ),
                          ),
                          Text(
                            item['subtitulo'],
                            style: TextStyle(
                              fontSize: 11,
                              color: (item['colorIcon'] as Color).withOpacity(
                                0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Tiendas disponibles
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tiendas disponibles',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2C2A),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTiendaChip('🛒', 'Éxito'),
                    _buildTiendaChip('🏪', 'Olímpica'),
                    _buildTiendaChip('🏬', 'Surtifamiliar'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTiendaChip(String emoji, String nombre) {
    return GestureDetector(
      onTap: () =>
          _enviarMensaje('¿Qué productos están más baratos en $nombre?'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE1F5EE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              nombre,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F6E56),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoInicial() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF1D9E75),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '¿En qué te ayudo hoy?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C2C2A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comparo precios entre Éxito, Olímpica y Surtifamiliar',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBurbuja(Map<String, dynamic> msg) {
    final esUsuario = msg['rol'] == 'usuario';
    final texto = msg['texto'] ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: esUsuario
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: SelectionArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: esUsuario ? const Color(0xFF1D9E75) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(esUsuario ? 16 : 4),
                    bottomRight: Radius.circular(esUsuario ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: esUsuario
                    ? Text(
                        texto,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      )
                    : MarkdownBody(
                        data: texto,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                            color: Color(0xFF2C2C2A),
                            fontSize: 14,
                          ),
                        ),
                        onTapLink: (text, href, title) {
                          if (href != null) {
                            launchUrl(
                              Uri.parse(href),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
              ),
            ),
          ),
          if (esUsuario) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildBurbujaCargando() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _buscandoEnTiendas
                  ? const Color(0xFF1976D2)
                  : const Color(0xFF1D9E75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _buscandoEnTiendas
                  ? Icons.shopping_cart_rounded
                  : Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buscandoEnTiendas
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Buscando en tiendas...',
                        style: TextStyle(
                          color: Color(0xFF1976D2),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : AnimatedBuilder(
                    animation: _dotController,
                    builder: (context, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final delay = i / 3;
                          final value = ((_dotController.value - delay) % 1.0)
                              .abs();
                          return Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                Colors.grey[300],
                                const Color(0xFF1D9E75),
                                value < 0.5 ? value * 2 : (1 - value) * 2,
                              ),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
