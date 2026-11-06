import '../lib/logic/urdu_speech.dart';

void main() {
  for (final s in [
    'آپ نے بتایا: پیٹرول 300 روپے اور چائے 200 روپے، کل 500 روپے۔',
    'نقد میں اب 4,250 روپے باقی ہیں۔',
    'آج آپ نے 1250.5 روپے خرچ کیے۔',
    'کل 12 مارچ تھی',
  ]) {
    print(UrduSpeech.spokenDigits(s));
  }
  for (final s in ['haan bilkul theek hai save kar do', 'نہیں، چائے 250 کی تھی', 'ہاں جی', 'aur 100 ki chai', 'ok kardo']) {
    print('$s -> yes=${UrduSpeech.saysYes(s)} no=${UrduSpeech.saysNo(s)} cls=${UrduSpeech.classify(s)}');
  }
}
