// F-Droid flavour entry point — enables reproducible builds by setting isFdroidBuild.

import 'main.dart' as m;

void main(List<String> args) {
  m.isFdroidBuild = true;
  m.main(args);
}
