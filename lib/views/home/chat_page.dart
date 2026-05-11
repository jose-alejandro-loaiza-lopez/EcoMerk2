import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ecomerk2/data/services/navigation_mode_service.dart';
import 'package:ecomerk2/data/services/chat_api_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Mensajes locales con id para el cursor de paginación
  final List<Map<String, dynamic>> _mensajes = [];
  bool _cargando = false;
  bool _cargandoHistorial = true;
  bool _hayMas = false;
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
    _cargarHistorial();
  }

  // Carga el historial desde el backend al abrir el chat
  Future<void> _cargarHistorial() async {
    setState(() => _cargandoHistorial = true);

    final data = await ChatApiService.obtenerMensajes();

    if (data != null && mounted) {
      final mensajes = List<Map<String, dynamic>>.from(data['mensajes'] ?? []);
      
      // El servidor devuelve orden descendente (más reciente primero)
      // Invertimos para mostrar cronológicamente
      final mensajesOrdenados = mensajes.reversed.toList();

      setState(() {
        _mensajes.clear();
        for (final m in mensajesOrdenados) {
          _mensajes.add({
            'id': m['id'],
            'rol': m['esIa'] == true ? 'ia' : 'usuario',
            'texto': m['contenido'],
          });
        }
        _hayMas = data['hayMas'] == true;
        if (mensajes.isNotEmpty) {
          _cursorAntes = mensajes.last['id']; // el de menor id para cargar más
        }
        _cargandoHistorial = false;
      });

      _scrollAbajo();
    } else {
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  // Cargar mensajes más antiguos (scroll hacia arriba)
  Future<void> _cargarMas() async {
    if (!_hayMas || _cursorAntes == null) return;

    final data = await ChatApiService.obtenerMensajes(antes: _cursorAntes);
    if (data != null && mounted) {
      final mensajes = List<Map<String, dynamic>>.from(data['mensajes'] ?? []);
      final mensajesOrdenados = mensajes.reversed.toList();

      setState(() {
        for (final m in mensajesOrdenados) {
          _mensajes.insert(0, {
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
  }

  Future<void> _enviarMensaje(String texto) async {
    if (texto.trim().isEmpty) return;
    _controller.clear();

    // Agregar mensaje del usuario localmente
    setState(() {
      _mensajes.add({'rol': 'usuario', 'texto': texto});
      _cargando = true;
    });
    _scrollAbajo();

    // Guardar mensaje del usuario en el backend
    await ChatApiService.guardarMensaje(contenido: texto, esIa: false);

    // Generar respuesta simulada
    await Future.delayed(const Duration(seconds: 1));
    final respuesta = _generarRespuestaSimulada(texto);

    if (mounted) {
      setState(() {
        _mensajes.add({'rol': 'ia', 'texto': respuesta});
        _cargando = false;
      });
      _scrollAbajo();

      // Guardar respuesta de la IA en el backend
      await ChatApiService.guardarMensaje(contenido: respuesta, esIa: true);
    }
  }

  String _generarRespuestaSimulada(String pregunta) {
    final p = pregunta.toLowerCase();
    if (p.contains('receta') || p.contains('cocinar') || p.contains('comer')) {
      return '🍽️ ¡Claro! Con los productos de tu lista puedo sugerirte varias recetas económicas. '
          'Por ejemplo, con arroz y pollo puedes hacer un delicioso arroz con pollo al estilo colombiano. '
          'Solo necesitas: arroz, pollo, cebolla, ajo, tomate y especias. '
          '¿Quieres que busque los precios de estos ingredientes en Éxito y Olímpica?';
    }
    if (p.contains('ahorro') || p.contains('barato') || p.contains('precio')) {
      return '💰 Para ahorrar en tu mercado semanal te recomiendo:\n\n'
          '1. Compara precios usando el buscador de EcoMerca2\n'
          '2. Revisa tus favoritos para ver cuándo bajan de precio\n'
          '3. Compra granos y enlatados en mayor cantidad\n\n'
          '¿Quieres que compare algún producto específico entre Éxito y Olímpica?';
    }
    if (p.contains('éxito') || p.contains('olímpica') || p.contains('tienda')) {
      return '🏪 Puedo ayudarte a comparar precios entre Éxito y Olímpica. '
          'Usa el buscador de la app para ver en tiempo real cuál tienda tiene el precio más bajo. '
          '¿Qué producto quieres comparar?';
    }
    return '🤖 Entiendo tu consulta. Como asistente de EcoMerca2, puedo ayudarte con:\n\n'
        '• Sugerencias de recetas basadas en tu lista\n'
        '• Consejos para ahorrar en el mercado\n'
        '• Comparación de precios entre Éxito y Olímpica\n\n'
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
        actions: [
          // Botón para cargar mensajes más antiguos
          if (_hayMas)
            IconButton(
              onPressed: _cargarMas,
              icon: const Icon(Icons.history, color: Colors.white),
              tooltip: 'Cargar mensajes anteriores',
            ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Estado de carga del historial
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
                    style: TextStyle(
                      color: Color(0xFF0F6E56),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // Botón para cargar más mensajes antiguos
          if (_hayMas && !_cargandoHistorial)
            GestureDetector(
              onTap: _cargarMas,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: const Color(0xFFE1F5EE),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.keyboard_arrow_up,
                        color: Color(0xFF1D9E75), size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Cargar mensajes anteriores',
                      style: TextStyle(
                        color: Color(0xFF1D9E75),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: _cargandoHistorial
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1D9E75),
                    ),
                  )
                : _mensajes.isEmpty
                    ? _buildEstadoInicial()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _mensajes.length + (_cargando ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _mensajes.length && _cargando) {
                            return _buildBurbujaCargando();
                          }
                          return _buildBurbuja(_mensajes[index]);
                        },
                      ),
          ),

          // Input de mensaje
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Pregúntame sobre recetas o precios...',
                      hintStyle:
                          TextStyle(color: Colors.grey[400], fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                  onTap: () => _enviarMensaje(_controller.text),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _cargando
                          ? Colors.grey[300]
                          : const Color(0xFF1D9E75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.send_rounded,
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
                      color: const Color(0xFFE8E8E8), width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Color(0xFF1D9E75), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF2C2C2A))),
                    ),
                    const Icon(Icons.chevron_right,
                        color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBurbuja(Map<String, dynamic> msg) {
    final esUsuario = msg['rol'] == 'usuario';
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
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: esUsuario
                    ? const Color(0xFF1D9E75)
                    : Colors.white,
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
              child: Text(
                msg['texto'] ?? '',
                style: TextStyle(
                  color: esUsuario
                      ? Colors.white
                      : const Color(0xFF2C2C2A),
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
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPuntoAnimado(0),
                const SizedBox(width: 4),
                _buildPuntoAnimado(1),
                const SizedBox(width: 4),
                _buildPuntoAnimado(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuntoAnimado(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.grey[300],
              const Color(0xFF1D9E75),
              value,
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}