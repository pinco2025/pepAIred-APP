import 'package:flutter_test/flutter_test.dart';
import 'package:prepaired/models/test_models.dart';

void main() {
  group('LocalTest Models', () {
    test('LocalOption fromJson', () {
      final json = {'id': 'a', 'text': 'Option A', 'image': 'url'};
      final option = LocalOption.fromJson(json);
      expect(option.id, 'a');
      expect(option.text, 'Option A');
      expect(option.image, 'url');
    });

    test('LocalQuestion fromJson', () {
      final json = {
        'id': 'q1',
        'uuid': 'uuid1',
        'text': 'Question Text',
        'options': [
          {'id': 'a', 'text': 'A'},
          {'id': 'b', 'text': 'B'}
        ],
        'section': 'Physics'
      };
      final question = LocalQuestion.fromJson(json);
      expect(question.id, 'q1');
      expect(question.uuid, 'uuid1');
      expect(question.options.length, 2);
      expect(question.section, 'Physics');
    });

    test('LocalTest fromJson', () {
      final json = {
        'id': 'test1',
        'testId': 'test1',
        'title': 'Test Title',
        'duration': 3600,
        'questions': [
           {
            'id': 'q1',
            'uuid': 'uuid1',
            'text': 'Question Text',
            'options': [],
            'section': 'Physics'
          }
        ],
        'sections': [{'name': 'Physics'}]
      };
      final testModel = LocalTest.fromJson(json);
      expect(testModel.id, 'test1');
      expect(testModel.title, 'Test Title');
      expect(testModel.duration, 3600);
      expect(testModel.questions.length, 1);
      expect(testModel.sections.length, 1);
    });
  });
}
