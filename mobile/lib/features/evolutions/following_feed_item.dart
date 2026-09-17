import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';

final class FollowingFeedItem {
  const FollowingFeedItem({
    required this.evolution,
    required this.car,
  });

  factory FollowingFeedItem.fromJson(Map<String, Object?> json) {
    return FollowingFeedItem(
      evolution: Evolution.fromJson(
        json['evolucao']! as Map<String, Object?>,
      ),
      car: Car.fromJson(json['carro']! as Map<String, Object?>),
    );
  }

  final Evolution evolution;
  final Car car;
}
