import 'package:flutter/material.dart';
import 'package:ecomerk2/controllers/favorites/price_alert_controller.dart';

/// Botón de campana que permite al usuario suscribirse o cancelar
/// alertas de precio para un producto de su lista de favoritos.
///
/// Gestiona su propio estado de carga (async) y delega la lógica
/// a [PriceAlertController].
///
/// Usa [productLink] como identificador único del producto para evitar
/// colisiones entre productos con el mismo nombre.
class PriceAlertButton extends StatefulWidget {
  /// Link único del producto (usado como clave de la alerta).
  final String productLink;

  /// Nombre legible del producto (para mostrar en notificaciones y snackbars).
  final String nombreProducto;

  /// Precio de referencia para detectar cambios (puede ser null si
  /// el producto no tiene precio guardado).
  final double? precioReferencia;

  const PriceAlertButton({
    super.key,
    required this.productLink,
    required this.nombreProducto,
    this.precioReferencia,
  });

  @override
  State<PriceAlertButton> createState() => _PriceAlertButtonState();
}

class _PriceAlertButtonState extends State<PriceAlertButton>
    with SingleTickerProviderStateMixin {
  final PriceAlertController _controller = PriceAlertController();

  bool _suscrito = false;
  bool _cargando = true;

  // Animación de escala al activar/desactivar
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.8,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _animController;

    _verificarEstado();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _verificarEstado() async {
    final suscrito = await _controller.estasSuscrito(widget.productLink);
    if (mounted) {
      setState(() {
        _suscrito = suscrito;
        _cargando = false;
      });
    }
  }

  Future<void> _toggleAlerta() async {
    // Animación de rebote
    await _animController.reverse();
    _animController.forward();

    setState(() => _cargando = true);

    if (_suscrito) {
      await _controller.cancelar(widget.productLink);
      if (mounted) {
        setState(() {
          _suscrito = false;
          _cargando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_off_outlined,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Alerta desactivada para "${widget.nombreProducto}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.grey[700],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await _controller.suscribir(
        widget.productLink,
        widget.nombreProducto,
        widget.precioReferencia,
      );
      if (mounted) {
        setState(() {
          _suscrito = true;
          _cargando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Alerta activada! Te avisamos si baja el precio de '
                    '"${widget.nombreProducto}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1D9E75),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Color(0xFF1D9E75),
            ),
          ),
        ),
      );
    }

    return ScaleTransition(
      scale: _scaleAnim,
      child: Tooltip(
        message: _suscrito ? 'Cancelar alerta de precio' : 'Activar alerta de precio',
        child: GestureDetector(
          onTap: _toggleAlerta,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _suscrito
                  ? const Color(0xFF1D9E75).withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _suscrito
                  ? Icons.notifications_active
                  : Icons.notifications_none_outlined,
              color: _suscrito ? const Color(0xFF1D9E75) : Colors.grey,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
