import 'package:raycasting_game/app/app.dart';
import 'package:raycasting_game/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
