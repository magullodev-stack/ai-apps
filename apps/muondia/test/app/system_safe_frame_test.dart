import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muondia/app/system_safe_frame.dart';

void main() {
  testWidgets('El marco común deja libres las bandas nativas superior e inferior', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(top: 28, bottom: 32),
        ),
        child: MuondiaSystemSafeFrame(
          child: SafeArea(
            child: Scaffold(
              body: Column(
                children: const [
                  SizedBox(key: Key('content-start'), height: 30),
                  Spacer(),
                  SizedBox(key: Key('content-end'), height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.getTopLeft(find.byKey(const Key('content-start'))).dy, 28);
    expect(tester.getBottomLeft(find.byKey(const Key('content-end'))).dy, 812);
    final frame = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
    );
    expect(frame.value.statusBarColor, Colors.black);
    expect(frame.value.systemNavigationBarColor, Colors.black);
    expect(tester.takeException(), isNull);
  });
}
