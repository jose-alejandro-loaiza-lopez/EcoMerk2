
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/services/navigation_mode_service.dart';
import '../data/services/user_api_service.dart';

class MainWrapper extends StatefulWidget {
  final Widget child;

  const MainWrapper({super.key, required this.child});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  @override
  void initState() {
    super.initState();
    NavigationModeService.instance.addListener(_onNavigationModeChanged);
    NavigationModeService.instance.load();
    _cargarFavs();
  }

  @override
  void dispose() {
    NavigationModeService.instance.removeListener(_onNavigationModeChanged);
    super.dispose();
  }

  void _onNavigationModeChanged() {
    if (mounted) setState(() {});
  }

  int _calcularIndice(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/favorites')) return 2;
    if (location.startsWith('/chat')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/search');
        break;
      case 2:
        context.go('/favorites');
        break;
      case 3:
        context.go('/chat');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  int _countFavs = 0;

  Future<void> _cargarFavs() async {
    final userId = await ApiService.obtenerUserId();
    if (userId != null) {
      final user = await ApiService.obtenerUsuario(userId);
      if (user != null && mounted) {
        final f = List.from(
          user['favoritos'] ?? user['alimentosFavoritos'] ?? [],
        );
        setState(() {
          _countFavs = f.length;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calcularIndice(context);
    final showBottomNav = NavigationModeService.instance.isBottomNavMode;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: showBottomNav
          ? _buildBottomNav(currentIndex, context)
          : null,
    );
  }

  Widget _buildBottomNav(int currentIndex, BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                Icons.home_rounded,
                'Inicio',
                currentIndex == 0,
                () => _onItemTapped(0, context),
              ),
              _buildNavItem(
                Icons.search_rounded,
                'Búsqueda',
                currentIndex == 1,
                () => _onItemTapped(1, context),
              ),
              _buildNavItemCenter(
                currentIndex == 2,
                () => _onItemTapped(2, context),
              ),
              _buildNavItem(
                Icons.auto_awesome_rounded,
                'IA',
                currentIndex == 3,
                () => _onItemTapped(3, context),
              ),
              _buildNavItem(
                Icons.person_rounded,
                'Perfil',
                currentIndex == 4,
                () => _onItemTapped(4, context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool activo,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: activo
            ? BoxDecoration(
                color: const Color(0xFFE1F5EE),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: activo ? const Color(0xFF1D9E75) : const Color(0xFF888780),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                color: activo
                    ? const Color(0xFF1D9E75)
                    : const Color(0xFF888780),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItemCenter(bool activo, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: activo ? const Color(0xFF0F6E56) : const Color(0xFF1D9E75),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D9E75).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.shopping_cart_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          if (_countFavs > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFD4537E),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _countFavs > 9 ? '9+' : '$_countFavs',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
