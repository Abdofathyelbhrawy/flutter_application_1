import 'dart:io';

void main() async {
  final regularUrl = 'https://github.com/googlefonts/cairo/raw/main/fonts/ttf/Cairo-Regular.ttf';
  final boldUrl = 'https://github.com/googlefonts/cairo/raw/main/fonts/ttf/Cairo-Bold.ttf';
  
  final regularFile = File('assets/fonts/Cairo-Regular.ttf');
  final boldFile = File('assets/fonts/Cairo-Bold.ttf');
  
  await regularFile.create(recursive: true);
  
  final req1 = await HttpClient().getUrl(Uri.parse(regularUrl));
  final res1 = await req1.close();
  await res1.pipe(regularFile.openWrite());
  print('Cairo-Regular.ttf downloaded');
  
  final req2 = await HttpClient().getUrl(Uri.parse(boldUrl));
  final res2 = await req2.close();
  await res2.pipe(boldFile.openWrite());
  print('Cairo-Bold.ttf downloaded');
}
