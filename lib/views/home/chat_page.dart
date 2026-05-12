
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ecomerk2/data/services/navigation_mode_service.dart';
import 'package:ecomerk2/data/services/chat_api_service.dart';

/// Página de chat privado con la IA del usuario.
///
/// Integra los endpoints reales del backend:
///   GET  /chat/mensajes[?antes=<id>] — cargar historial (10 por página)
///   POST /chat/mensajes              — guardar mensajes (usuario e IA)
///
/// La respuesta de la IA se genera de forma local (simulada) y luego
/// se persiste en el backend con `esIa: true`.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Lista de mensajes en orden cronológico (el último es el más reciente).
  final List<MensajeChat> _mensajes = [];

  bool _cargando = false;
  bool _cargandoHistorial = false;
  bool _hayMasHistorial = false;

  /// ID del mensaje más antiguo cargado, para paginar hacia atrás.
  int? _cursorAntes;

  final List<String> _sugerencias = [
    '¿Qué puedo cocinar con arroz y pollo?',
    '¿Cómo ahorro en mi mercado semanal?',
    '¿Qué productos están más baratos en Éxito?',
    'Dame una receta económica para 4 personas',
  ];

  @override
  void initState() {
    super.initState();
    _cargarHistorial(inicial: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ── Scroll infinito hacia arriba ───────────────────────────────────────────

  void _onScroll() {
    if (_scrollController.position.pixels <= 50 &&
        _hayMasHistorial &&
        !_cargandoHistorial) {
      _cargarHistorial(inicial: false);
    }
  }

  // ── Cargar historial desde el backend ─────────────────────────────────────

  Future<void> _cargarHistorial({required bool inicial}) async {
    if (_cargandoHistorial) return;
    setState(() => _cargandoHistorial = true);

    try {
      final resultado = await ChatApiService.obtenerMensajes(
        antes: inicial ? null : _cursorAntes,
      );

      if (resultado != null && mounted) {
        // El backend devuelve los mensajes ordenados descendente (más reciente primero)
        // Invertimos para mostrar el más antiguo arriba
        final nuevos = resultado.mensajes.reversed.toList();

        setState(() {
          if (inicial) {
            _mensajes.clear();
          }
          // Insertar al inicio (son mensajes más antiguos)
          _mensajes.insertAll(0, nuevos);
          _hayMasHistorial = resultado.hayMas;

          if (nuevos.isNotEmpty) {
            // El cursor apunta al id más pequeño cargado (el más antiguo)
            _cursorAntes = _mensajes.first.id;
          }
        });

        if (inicial) _scrollAbajo();
      }
    } catch (e) {
      debugPrint('[ChatPage] Error cargando historial: $e');
    } finally {
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  // ── Enviar mensaje ─────────────────────────────────────────────────────────

  Future<void> _enviarMensaje(String texto) async {
    final contenido = texto.trim();
    if (contenido.isEmpty) return;
    _controller.clear();

    setState(() => _cargando = true);
    _scrollAbajo();

    try {
      // 1. Guardar mensaje del usuario en el backend
      final mensajeUsuario = await ChatApiService.guardarMensaje(
        contenido: contenido,
        esIa: false,
      );

      if (mensajeUsuario != null && mounted) {
        setState(() => _mensajes.add(mensajeUsuario));
        _scrollAbajo();
      } else {
        // Si falla el guardado, igual mostramos localmente
        final fallback = MensajeChat(
          id: DateTime.now().millisecondsSinceEpoch,
          usuarioId: 0,
          contenido: contenido,
          esIa: false,
        );
        if (mounted) setState(() => _mensajes.add(fallback));
        _scrollAbajo();
      }

      // 2. Generar respuesta de la IA (simulada)
      await Future.delayed(const Duration(milliseconds: 800));
      final respuesta = _generarRespuestaSimulada(contenido);

      // 3. Guardar respuesta de la IA en el backend
      final mensajeIa = await ChatApiService.guardarMensaje(
        contenido: respuesta,
        esIa: true,
      );

      if (mounted) {
        setState(() {
          _cargando = false;
          if (mensajeIa != null) {
            _mensajes.add(mensajeIa);
          } else {
            // Fallback local si el guardado falla
            _mensajes.add(MensajeChat(
              id: DateTime.now().millisecondsSinceEpoch + 1,
              usuarioId: 0,
              contenido: respuesta,
              esIa: true,
            ));
          }
        });
        _scrollAbajo();
      }
    } catch (e) {
      debugPrint('[ChatPage] Error enviando mensaje: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── Respuesta simulada (IA local) ──────────────────────────────────────────

  String _generarRespuestaSimulada(String pregunta) {
    final p = pregunta.toLowerCase();
    if (p.contains('receta') || p.contains('cocinar') || p.contains('comer')) {
      return '🍽️ ¡Claro! Con los productos de tu lista puedo sugerirte varias recetas económicas. '
          'Por ejemplo, con arroz y pollo puedes hacer un delicioso arroz con pollo al estilo colombiano. '
          'Solo necesitas: arroz, pollo, cebolla, ajo, tomate y especias. '
          '¿Quieres que busque los precios de estos ingredientes en Éxito, Olímpica y Surtifamiliar?';
    }
    if (p.contains('ahorro') || p.contains('barato') || p.contains('precio')) {
      return '💰 Para ahorrar en tu mercado semanal te recomiendo:\n\n'
          '1. Compara precios usando el buscador de EcoMerca2\n'
          '2. Revisa tus favoritos para ver cuándo bajan de precio\n'
          '3. Compra granos y enlatados en mayor cantidad\n\n'
          '¿Quieres que compare algún producto específico entre Éxito, Olímpica y Surtifamiliar?';
    }
    if (p.contains('éxito') ||
        p.contains('olímpica') ||
        p.contains('surtifamiliar') ||
        p.contains('tienda')) {
      return '🏪 Puedo ayudarte a comparar precios entre Éxito, Olímpica y Surtifamiliar. '
          'Usa el buscador de la app para ver en tiempo real cuál tienda tiene el precio más bajo. '
          '¿Qué producto quieres comparar?';
    }
    return '🤖 Entiendo tu consulta. Como asistente de EcoMerca2, puedo ayudarte con:\n\n'
        '• Sugerencias de recetas basadas en tu lista\n'
        '• Consejos para ahorrar en el mercado\n'
        '• Comparación de precios entre Éxito, Olímpica y Surtifamiliar\n\n'
        '¿En qué más te ayudo?';
  }

  void _scrollAbajo() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistente IA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'EcoMerca2',
                  style: TextStyle(color: Color(0xFF9FE1CB), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_hayMasHistorial)
            TextButton(
              onPressed: () => _cargarHistorial(inicial: false),
              child: const Text(
                'Ver más',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Indicador cargando historial
          if (_cargandoHistorial && _mensajes.isEmpty)
            const LinearProgressIndicator(
              color: Color(0xFF1D9E75),
              backgroundColor: Color(0xFFE1F5EE),
            ),

          // Cuerpo del chat
          Expanded(
            child: (_mensajes.isEmpty && !_cargandoHistorial)
                ? _buildEstadoInicial()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _mensajes.length +
                        (_cargandoHistorial ? 1 : 0) +
                        (_cargando ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Spinner de carga de historial al inicio
                      if (_cargandoHistorial && index == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1D9E75),
                              ),
                            ),
                          ),
                        );
                      }
                      final msgIndex =
                          index - (_cargandoHistorial ? 1 : 0);
                      // Spinner de respuesta IA al final
                      if (_cargando && msgIndex == _mensajes.length) {
                        return _buildBurbujaCargando();
                      }
                      if (msgIndex < 0 || msgIndex >= _mensajes.length) {
                        return const SizedBox.shrink();
                      }
                      return _buildBurbuja(_mensajes[msgIndex]);
                    },
                  ),
          ),

          // Input
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    enabled: !_cargando,
                    decoration: InputDecoration(
                      hintText: 'Pregúntame sobre recetas o precios...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _enviarMensaje,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _cargando
                      ? null
                      : () => _enviarMensaje(_controller.text),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _cargando
                          ? Colors.grey
                          : const Color(0xFF1D9E75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
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
            'Pregúntame sobre recetas, precios o cómo ahorrar en tu mercado',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 24),
          ..._sugerencias.map(
            (s) => GestureDetector(
              onTap: () => _enviarMensaje(s),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE8E8E8),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF1D9E75),
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2C2C2A),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBurbuja(MensajeChat msg) {
    final esUsuario = !msg.esIa;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esUsuario) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF1D9E75),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.contenido,
                style: TextStyle(
                  color:
                      esUsuario ? Colors.white : const Color(0xFF2C2C2A),
                  fontSize: 14,
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
              color: const Color(0xFF1D9E75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPunto(),
                const SizedBox(width: 4),
                _buildPunto(),
                const SizedBox(width: 4),
                _buildPunto(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPunto() {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }
}