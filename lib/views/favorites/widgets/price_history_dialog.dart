import 'package:flutter/material.dart';
import 'package:ecomerk2/data/services/product_api_service.dart';

/// Diálogo que muestra el historial de precios de un producto.
///
/// Usa el endpoint GET /productos/{productId}/precios (docs.md sección 4)
/// para obtener el historial ordenado por fecha descendente.
class PriceHistoryDialog extends StatefulWidget {
  final String productId;
  final String productName;

  const PriceHistoryDialog({
    super.key,
    required this.productId,
    required this.productName,
  });

  /// Muestra el diálogo como un bottom sheet modal.
  static void show(BuildContext context,
      {required String productId, required String productName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PriceHistoryDialog(
        productId: productId,
        productName: productName,
      ),
    );
  }

  @override
  State<PriceHistoryDialog> createState() => _PriceHistoryDialogState();
}

class _PriceHistoryDialogState extends State<PriceHistoryDialog>
    with SingleTickerProviderStateMixin {
  List<dynamic> _historial = [];
  bool _cargando = true;
  String? _error;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _cargarHistorial();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    try {
      final data = await ProductApiService.obtenerHistorial(widget.productId);
      if (data != null && mounted) {
        setState(() {
          _historial = List.from(data['historial'] ?? []);
          _cargando = false;
        });
        _animController.forward();
      } else if (mounted) {
        setState(() {
          _historial = [];
          _cargando = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar el historial';
          _cargando = false;
        });
      }
    }
  }

  String _formatearPrecio(double precio) {
    return precio.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  String _formatearFecha(String fechaIso) {
    try {
      final fecha = DateTime.parse(fechaIso);
      final meses = [
        '',
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic'
      ];
      return '${fecha.day} ${meses[fecha.month]} ${fecha.year} · ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return fechaIso;
    }
  }

  /// Calcula el cambio de precio respecto al registro anterior.
  /// Retorna null si no hay comparación posible.
  double? _calcularCambio(int index) {
    if (index >= _historial.length - 1) return null;
    final precioActual = (_historial[index]['precio'] as num).toDouble();
    final precioAnterior = (_historial[index + 1]['precio'] as num).toDouble();
    if (precioAnterior == 0) return null;
    return ((precioActual - precioAnterior) / precioAnterior) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAFAFA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D9E75).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.timeline_rounded,
                        color: Color(0xFF1D9E75),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Historial de precios',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C2C2A),
                            ),
                          ),
                          Text(
                            widget.productName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: _cargando
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF1D9E75),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Cargando historial...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red[300], size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _cargando = true;
                                      _error = null;
                                    });
                                    _cargarHistorial();
                                  },
                                  child: const Text(
                                    'Reintentar',
                                    style: TextStyle(color: Color(0xFF1D9E75)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _historial.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.history,
                                        color: Colors.grey[300], size: 56),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Sin historial de precios',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Aún no se han registrado precios\npara este producto',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : FadeTransition(
                                opacity: _fadeAnim,
                                child: Column(
                                  children: [
                                    // Resumen arriba
                                    if (_historial.length >= 2)
                                      _buildResumen(),
                                    // Lista de precios
                                    Expanded(
                                      child: ListView.builder(
                                        controller: scrollController,
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 8, 16, 24),
                                        itemCount: _historial.length,
                                        itemBuilder: (context, index) {
                                          return _buildPrecioItem(index);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResumen() {
    final primerPrecio =
        (_historial.last['precio'] as num).toDouble();
    final ultimoPrecio =
        (_historial.first['precio'] as num).toDouble();
    final cambioTotal =
        ((ultimoPrecio - primerPrecio) / primerPrecio) * 100;
    final subio = cambioTotal > 0;
    final bajo = cambioTotal < 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bajo
            ? const Color(0xFFE8F9F1)
            : subio
                ? const Color(0xFFFFF0F0)
                : Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bajo
              ? const Color(0xFF1D9E75).withOpacity(0.3)
              : subio
                  ? Colors.red.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            bajo
                ? Icons.trending_down_rounded
                : subio
                    ? Icons.trending_up_rounded
                    : Icons.trending_flat_rounded,
            color: bajo
                ? const Color(0xFF1D9E75)
                : subio
                    ? Colors.red[400]
                    : Colors.grey,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bajo
                      ? 'El precio ha bajado'
                      : subio
                          ? 'El precio ha subido'
                          : 'El precio se mantiene',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: bajo
                        ? const Color(0xFF0F6E56)
                        : subio
                            ? Colors.red[700]
                            : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cambioTotal.abs().toStringAsFixed(1)}% desde el primer registro',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${_formatearPrecio(ultimoPrecio)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C2C2A),
                ),
              ),
              Text(
                'Último precio',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrecioItem(int index) {
    final item = _historial[index];
    final precio = (item['precio'] as num).toDouble();
    final fecha = item['fechaGuardado']?.toString() ?? '';
    final cambio = _calcularCambio(index);
    final esPrimero = index == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: esPrimero
                      ? const Color(0xFF1D9E75)
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: esPrimero
                        ? const Color(0xFF0F6E56)
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
              ),
              if (index < _historial.length - 1)
                Container(
                  width: 2,
                  height: 50,
                  color: Colors.grey[200],
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: esPrimero ? Colors.white : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: esPrimero
                      ? const Color(0xFF1D9E75).withOpacity(0.3)
                      : Colors.grey.withOpacity(0.15),
                ),
                boxShadow: esPrimero
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1D9E75).withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (esPrimero)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D9E75),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ACTUAL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            Text(
                              _formatearFecha(fecha),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_formatearPrecio(precio)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: esPrimero
                                ? const Color(0xFF1D9E75)
                                : const Color(0xFF2C2C2A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cambio != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cambio < 0
                            ? const Color(0xFFE8F9F1)
                            : cambio > 0
                                ? const Color(0xFFFFF0F0)
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cambio < 0
                                ? Icons.arrow_drop_down
                                : cambio > 0
                                    ? Icons.arrow_drop_up
                                    : Icons.remove,
                            color: cambio < 0
                                ? const Color(0xFF1D9E75)
                                : cambio > 0
                                    ? Colors.red[400]
                                    : Colors.grey,
                            size: 18,
                          ),
                          Text(
                            '${cambio.abs().toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cambio < 0
                                  ? const Color(0xFF1D9E75)
                                  : cambio > 0
                                      ? Colors.red[400]
                                      : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
