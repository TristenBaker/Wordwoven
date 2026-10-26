import json
from pathlib import Path
import tempfile
import unittest
from playtest_telemetry import summarize


class ReportTest(unittest.TestCase):
    def test_duplicates_truncation_and_debug_separation(self):
        def event(seq, name, data, run='a', debug=False):
            return dict(schema_version=1, session_id='s', sequence=seq,
                        run_id=run, debug_used=debug, event=name, data=data,
                        build=dict(branch='test', commit='abc', dirty=False))
        rows = [event(1, 'run_started', {}),
                event(2, 'word_resolved', dict(damage=10, elapsed_seconds=3)),
                event(3, 'word_rejected', {}),
                event(4, 'run_ended', dict(outcome='won')),
                event(5, 'run_started', {}, run='b'),
                event(6, 'debug_toggled', {}, run='b', debug=True)]
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / 'first.jsonl'
            second = Path(directory) / 'copy.jsonl'
            first.write_text('\n'.join(map(json.dumps, rows)) + '\n{broken')
            second.write_text('\n'.join(map(json.dumps, rows)))
            report = summarize([first, second])
        self.assertEqual(report['invalid_lines'], 1)
        clean, debug = report['builds']
        self.assertEqual(clean['runs'], 1)
        self.assertEqual(clean['rejection_rate'], .5)
        self.assertEqual(clean['outcomes'], {'won': 1})
        self.assertEqual(clean['median_cast_seconds'], 3)
        self.assertTrue(debug['debug_used'])
        self.assertEqual(debug['outcomes'], {'incomplete': 1})


if __name__ == '__main__':
    unittest.main()
