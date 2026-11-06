import '../lib/logic/expense_parser.dart';
import '../lib/logic/urdu_speech.dart';

void main() {
  for (final n in [0, 5, 19, 77, 79, 100, 300, 1250, 99999, 150000, 2500000]) {
    print('$n -> ${UrduSpeech.number(n)}');
  }
  print(UrduSpeech.money(450.5));
  print(UrduSpeech.greeting('وقاص', DateTime(2026, 11, 6, 22, 36)));
  print(UrduSpeech.greeting('وقاص', DateTime(2026, 11, 7, 9, 0)));
  final r = ExpenseParser.parse('aj 300 ka petrol aur 200 ki chai');
  print(UrduSpeech.repeatOrder(r, (s) => s));
  final r2 = ExpenseParser.parse('آج تین سو کا پیٹرول اور دو سو کی چائے');
  print(UrduSpeech.repeatOrder(r2, (s) => s));
  for (final s in ['جی ہاں', 'ہاں ٹھیک ہے۔', 'نہیں غلط ہے', 'haan theek hai', 'aur 100 ki chai', 'ok']) {
    print('$s -> ${UrduSpeech.classify(s)}');
  }
}
