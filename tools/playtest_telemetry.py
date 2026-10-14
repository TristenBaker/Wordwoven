"""Stamp export provenance or summarize offline playtest JSONL files."""
import argparse
import collections
import json
from pathlib import Path
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def stamp():
    def git(*args):
        return subprocess.check_output(
            ['git', '-C', str(ROOT), *args], text=True
        ).strip()
    build = dict(branch=git('rev-parse', '--abbrev-ref', 'HEAD'),
                 commit=git('rev-parse', 'HEAD'),
                 dirty=bool(git('status', '--porcelain')))
    path = ROOT / 'data' / 'telemetry_build.json'
    path.write_text(json.dumps(build, indent=2) + '\n', encoding='utf-8')
    print(path)
    print(json.dumps(build))


def summarize(paths):
    runs = collections.defaultdict(list)
    seen = set()
    invalid = 0
    for path in paths:
        for line in path.read_text(encoding='utf-8-sig').splitlines():
            try:
                row = json.loads(line)
                if row.get('schema_version') != 1:
                    raise ValueError('unsupported schema')
                key = (row['session_id'], row['sequence'])
                if key in seen:
                    continue
                seen.add(key)
                if row.get('run_id'):
                    runs[(row['session_id'], row['run_id'])].append(row)
            except (ValueError, KeyError, TypeError, AttributeError):
                invalid += 1
    groups = collections.defaultdict(list)
    for rows in runs.values():
        rows.sort(key=lambda row: row['sequence'])
        build = rows[0]['build']
        key = (build.get('branch'), build.get('commit'), build.get('dirty'),
               any(row.get('debug_used', False) for row in rows))
        groups[key].append(rows)
    report = []
    for (branch, commit, dirty, debug), group in sorted(
            groups.items(), key=lambda item: str(item[0])):
        outcomes = collections.Counter()
        accepted, rejected, damage, seconds = 0, 0, [], []
        for rows in group:
            endings = [r for r in rows if r['event'] == 'run_ended']
            outcomes[endings[-1]['data']['outcome'] if endings else
                     'incomplete'] += 1
            for row in rows:
                data = row['data']
                if row['event'] == 'word_rejected':
                    rejected += 1
                if row['event'] == 'word_resolved':
                    accepted += 1
                    if 'damage' in data:
                        damage.append(data['damage'])
                    if 'elapsed_seconds' in data:
                        seconds.append(data['elapsed_seconds'])
        report.append(dict(
            branch=branch, commit=commit, dirty=dirty, debug_used=debug,
            runs=len(group), outcomes=dict(outcomes), accepted=accepted,
            rejected=rejected,
            rejection_rate=rejected / (accepted + rejected)
            if accepted + rejected else None,
            mean_cast_damage=statistics.mean(damage) if damage else None,
            median_cast_seconds=statistics.median(seconds) if seconds else None,
        ))
    return dict(builds=report, invalid_lines=invalid)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['stamp', 'report'])
    parser.add_argument('directory', nargs='?', type=Path)
    args = parser.parse_args()
    if args.command == 'stamp':
        stamp()
    elif args.directory is None or not args.directory.is_dir():
        parser.error('report requires a directory containing JSONL files')
    else:
        paths = list(args.directory.rglob('*.jsonl'))
        if not paths:
            sys.exit('No JSONL files found')
        print(json.dumps(summarize(paths), indent=2))
