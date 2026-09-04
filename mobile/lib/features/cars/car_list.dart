import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/car.dart';

final class CarList extends StatefulWidget {
  const CarList({
    required this.title,
    required this.emptyMessage,
    required this.loader,
    required this.onCarTap,
    this.primaryActionLabel,
    this.onPrimaryAction,
    super.key,
  }) : assert(onPrimaryAction == null || primaryActionLabel != null);

  final String title;
  final String emptyMessage;
  final Future<List<Car>> Function() loader;
  final ValueChanged<Car> onCarTap;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  @override
  State<CarList> createState() => _CarListState();
}

class _CarListState extends State<CarList> {
  late Future<List<Car>> _cars;

  @override
  void initState() {
    super.initState();
    _cars = widget.loader();
  }

  Future<void> _reload() async {
    final next = widget.loader();
    setState(() => _cars = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: widget.onPrimaryAction == null
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.onPrimaryAction,
              icon: const Icon(Icons.add),
              label: Text(widget.primaryActionLabel!),
            ),
      body: FutureBuilder<List<Car>>(
        future: _cars,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              message: apiErrorMessage(snapshot.error!),
              actionLabel: 'Tentar novamente',
              onAction: _reload,
            );
          }
          final cars = snapshot.data ?? const <Car>[];
          if (cars.isEmpty) {
            return _MessageState(
              icon: Icons.directions_car_outlined,
              message: widget.emptyMessage,
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: cars.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _CarCard(
                car: cars[index],
                onTap: () => widget.onCarTap(cars[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

final class _CarCard extends StatelessWidget {
  const _CarCard({required this.car, required this.onTap});

  final Car car;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: car.photoUrl == null
                  ? const ColoredBox(
                      color: Color(0xFF24262A),
                      child: Icon(Icons.directions_car_rounded, size: 72),
                    )
                  : Image.network(
                      car.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFF24262A),
                        child: Icon(Icons.broken_image_outlined, size: 48),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [car.model, car.year]
                        .where((value) => value != null)
                        .join(' '),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('${car.ownerName}  @${car.ownerUsername}'),
                  if (car.projectStatus != null) ...[
                    const SizedBox(height: 12),
                    Chip(label: Text(car.projectStatus!)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
