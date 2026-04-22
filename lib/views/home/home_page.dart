import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ecomerk2/data/services/navigation_mode_service.dart';
import 'package:ecomerk2/data/services/user_api_service.dart';
import '../../widgets/custom_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String _nombre = '';
  List<Map<String, dynamic>> _favoritos = [];
  bool _cargando = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _categorias = [
    {
      'emoji': '🥦',
      'nombre': 'Verduras',
      'query': 'verduras',
      'color': const Color(0xFFE8F5E9),
      'colorIcon': const Color(0xFF388E3C),
    },
    {
      'emoji': '🥛',
      'nombre': 'Lácteos',
      'query': 'leche',
      'color': const Color(0xFFE3F2FD),
      'colorIcon': const Color(0xFF1976D2),
    },
    {
      'emoji': '🍗',
      'nombre': 'Carnes',
      'query': 'pollo',
      'color': const Color(0xFFFCE4EC),
      'colorIcon': const Color(0xFFC62828),
    },
    {
      'emoji': '🍞',
      'nombre': 'Panadería',
      'query': 'pan',
      'color': const Color(0xFFFFF8E1),
      'colorIcon': const Color(0xFFF9A825),
    },
    {
      'emoji': '🧴',
      'nombre': 'Aseo',
      'query': 'jabón',
      'color': const Color(0xFFE8EAF6),
      'colorIcon': const Color(0xFF3949AB),
    },
    {
      'emoji': '🥤',
      'nombre': 'Bebidas',
      'query': 'jugo',
      'color': const Color(0xFFF3E5F5),
      'colorIcon': const Color(0xFF7B1FA2),
    },
    {
      'emoji': '🍚',
      'nombre': 'Granos',
      'query': 'arroz',
      'color': const Color(0xFFFFF3E0),
      'colorIcon': const Color(0xFFE65100),
    },
    {
      'emoji': '🍳',
      'nombre': 'Aceites',
      'query': 'aceite',
      'color': const Color(0xFFE0F7FA),
      'colorIcon': const Color(0xFF00838F),
    },
  ];

  final List<Map<String, dynamic>> _ofertas = [
    {
      'emoji': '🛒',
      'titulo': 'Compara granos',
      'subtitulo': 'Arroz, lentejas, frijoles',
      'color': const Color(0xFF1D9E75),
      'query': 'arroz',
    },
    {
      'emoji': '🥛',
      'titulo': 'Lácteos del día',
      'subtitulo': 'Leche, queso, yogur',
      'color': const Color(0xFF1976D2),
      'query': 'leche',
    },
    {
      'emoji': '🍗',
      'titulo': 'Proteínas',
      'subtitulo': 'Pollo, carne, huevos',
      'color': const Color(0xFFC62828),
      'query': 'pollo',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _cargarUsuario();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _ejecutarBusqueda() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      context.go('/search', extra: query);
    }
  }

  Future<void> _cargarUsuario() async {
    final vigente = await ApiService.tokenEstaVigente();
    if (!vigente) {
      _redirigirLogin();
      return;
    }

    final id = await ApiService.obtenerUserId();
    if (id == null) {
      _redirigirLogin();
      return;
    }

    final usuario = await ApiService.obtenerUsuario(id);
    if (usuario == null) {
      if (mounted)
        setState(() {
          _nombre = 'Usuario';
          _cargando = false;
        });
      _animController.forward();
      return;
    }

    if (usuario['_tokenExpirado'] == true) {
      _redirigirLogin(mensaje: 'Tu sesión expiró. Inicia sesión nuevamente.');
      return;
    }

    if (mounted) {
      setState(() {
        _nombre = usuario['nombre'] ?? 'Usuario';
        // Campo correcto del backend es 'favoritos' y cada item es un objeto
        final raw = usuario['favoritos'] ?? usuario['alimentosFavoritos'] ?? [];
        _favoritos = List<Map<String, dynamic>>.from(
          (raw as List).map(
            (e) => e is Map<String, dynamic> ? e : {'nombre': e.toString()},
          ),
        );
        _cargando = false;
      });
      _animController.forward();
    }
  }

  void _redirigirLogin({String? mensaje}) async {
    await ApiService.borrarToken();
    if (!mounted) return;
    if (mensaje != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.orange),
      );
    }
    context.go('/login');
  }

  Future<void> _cerrarSesion() async {
    await ApiService.borrarToken();
    if (mounted) context.go('/login');
  }

  String _obtenerSaludo() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _obtenerIniciales() {
    if (_nombre.isEmpty) return 'U';
    final partes = _nombre.trim().split(' ');
    if (partes.length >= 2)
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    return _nombre[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F4F3),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
        ),
      );
    }

    final usarMenuLateral = NavigationModeService.instance.isDrawerMode;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      drawer: usarMenuLateral ? const CustomDrawer() : null,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(child: _buildHeader()),

                // ── Oferta del día ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            const Text(
                              'Descubre productos',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C2C2A),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => context.go('/search'),
                          child: const Text(
                            'Ver más',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1D9E75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      itemCount: _ofertas.length,
                      itemBuilder: (context, index) {
                        final oferta = _ofertas[index];
                        return GestureDetector(
                          onTap: () =>
                              context.go('/search', extra: oferta['query']),
                          child: Container(
                            width: 180,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  (oferta['color'] as Color),
                                  (oferta['color'] as Color).withOpacity(0.75),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: (oferta['color'] as Color).withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  oferta['emoji'],
                                  style: const TextStyle(fontSize: 26),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      oferta['titulo'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      oferta['subtitulo'],
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.search_rounded,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Comparar precios',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Categorías populares ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Categorías populares',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C2C2A),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/search'),
                          child: const Text(
                            'Ver todas',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1D9E75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 96,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categorias.length,
                      itemBuilder: (context, index) {
                        final cat = _categorias[index];
                        return GestureDetector(
                          onTap: () =>
                              context.go('/search', extra: cat['query']),
                          child: Container(
                            width: 76,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: cat['color'] as Color,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (cat['colorIcon'] as Color).withOpacity(
                                  0.15,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  cat['emoji'],
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  cat['nombre'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: cat['colorIcon'] as Color,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Tus favoritos ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFFD4537E),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Tus favoritos',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C2C2A),
                              ),
                            ),
                            if (_favoritos.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBF0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_favoritos.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFD4537E),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        GestureDetector(
                          onTap: () => context.go('/favorites'),
                          child: const Text(
                            'Ver todos',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1D9E75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                _favoritos.isEmpty
                    ? SliverToBoxAdapter(child: _buildEstadoVacioFavoritos())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final fav = _favoritos[index];
                          final nombre =
                              fav['nombre']?.toString() ?? 'Producto';
                          final tienda = fav['tienda']?.toString() ?? '';
                          final precio = fav['precio']?.toString() ?? '';
                          final imagen = fav['imagen']?.toString() ?? '';

                          return GestureDetector(
                            onTap: () => context.go('/favorites'),
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                                  // Imagen o ícono
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: imagen.isNotEmpty
                                        ? Image.network(
                                            imagen,
                                            width: 46,
                                            height: 46,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                _buildIconFav(),
                                          )
                                        : _buildIconFav(),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nombre,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2C2C2A),
                                          ),
                                        ),
                                        if (precio.isNotEmpty &&
                                            precio != r'$0')
                                          Text(
                                            '$precio · $tienda',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE1F5EE),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.compare_arrows_rounded,
                                          color: Color(0xFF0F6E56),
                                          size: 13,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Comparar',
                                          style: TextStyle(
                                            color: Color(0xFF0F6E56),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }, childCount: _favoritos.length),
                      ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconFav() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBF0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.favorite_rounded,
        color: Color(0xFFD4537E),
        size: 22,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1D9E75),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (NavigationModeService.instance.isDrawerMode) ...[
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _obtenerSaludo(),
                        style: const TextStyle(
                          color: Color(0xFF9FE1CB),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _cerrarSesion,
                    icon: const Icon(
                      Icons.logout,
                      color: Color(0xFF9FE1CB),
                      size: 22,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F6E56),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF5DCAA5),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _obtenerIniciales(),
                          style: const TextStyle(
                            color: Color(0xFF9FE1CB),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _ejecutarBusqueda(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar productos...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.grey,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _ejecutarBusqueda,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D9E75),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Buscar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildEstadoVacioFavoritos() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => context.go('/favorites'),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD6E4), width: 1),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBF0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  color: Color(0xFFD4537E),
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tu lista está vacía',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Agrega productos a tu lista para\ncompararlos entre tiendas',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4537E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Agregar productos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
