import 'package:flutter/material.dart';
import 'package:ecomerk2/data/services/api_service.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _productoController = TextEditingController();
  List<String> _lista = [];
  bool _loading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _cargarLista();
  }

  Future<void> _cargarLista() async {
    final id = await ApiService.obtenerUserId();
    if (id != null) {
      final usuario = await ApiService.obtenerUsuario(id);
      if (usuario != null && mounted) {
        setState(() {
          _userId = id;
          _lista = List<String>.from(
              usuario['alimentosFavoritos'] ?? []);
          _loading = false;
        });
      }
    }
  }

  Future<void> _agregarProducto() async {
    final nombre = _productoController.text.trim();
    if (nombre.isEmpty) return;

    final nuevaLista = [..._lista, nombre];
    setState(() => _lista = nuevaLista);
    _productoController.clear();

    if (_userId != null) {
      await ApiService.actualizarLista(_userId!, nuevaLista);
    }
  }

  Future<void> _eliminarProducto(int index) async {
    final nuevaLista = [..._lista];
    nuevaLista.removeAt(index);
    setState(() => _lista = nuevaLista);

    if (_userId != null) {
      await ApiService.actualizarLista(_userId!, nuevaLista);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mi lista de compras',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            )),
        backgroundColor: const Color(0xFF1D9E75),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1D9E75),
              ),
            )
          : Column(
              children: [
                // Campo para agregar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _productoController,
                          decoration: InputDecoration(
                            hintText: 'Agregar producto...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _agregarProducto(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _agregarProducto,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D9E75),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Lista
                Expanded(
                  child: _lista.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('🛒',
                                  style: TextStyle(fontSize: 64)),
                              SizedBox(height: 16),
                              Text('Tu lista está vacía',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF444441),
                                  )),
                              SizedBox(height: 8),
                              Text('Agrega productos arriba',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  )),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _lista.length,
                          itemBuilder: (context, index) {
                            return Dismissible(
                              key: Key('$index-${_lista[index]}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) =>
                                  _eliminarProducto(index),
                              child: Container(
                                margin:
                                    const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.04),
                                      blurRadius: 4,
                                    )
                                  ],
                                ),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.shopping_cart_outlined,
                                    color: Color(0xFF1D9E75),
                                  ),
                                  title: Text(
                                    _lista[index],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF2C2C2A),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _eliminarProducto(index),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}