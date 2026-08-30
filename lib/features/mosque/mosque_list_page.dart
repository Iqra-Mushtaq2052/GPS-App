import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/db/app_database.dart';
import 'add_mosque_page.dart';

class MosqueListPage extends StatelessWidget {
  const MosqueListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Masjidein')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddMosquePage()),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Mosque>>(
        stream: scope.mosqueRepository.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final mosques = snapshot.data!;
          if (mosques.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Abhi koi masjid save nahi hui. + button se ek add karein.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: mosques.length,
            itemBuilder: (context, index) {
              final mosque = mosques[index];
              return ListTile(
                leading: const Icon(Icons.mosque),
                title: Text(mosque.name),
                subtitle: Text('Radius: ${mosque.radiusMeters}m'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: mosque.isEnabled,
                      onChanged: (value) async {
                        await scope.mosqueRepository.update(
                          mosque.copyWith(isEnabled: value),
                        );
                        await scope.proximity.refreshMosques();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await scope.mosqueRepository.delete(mosque.id);
                        await scope.proximity.refreshMosques();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
