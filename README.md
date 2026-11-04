# insights-facts

An Ansible playbook that generates an [insights-client](https://github.com/RedHatInsights/insights-client) archive locally, without uploading it, extracts it, and publishes selected archive contents as Ansible **local facts**. The result is readable as `ansible_local.insights` in any later play on the same host.

## Files

| File | Purpose |
| --- | --- |
| `insights_facts.yml` | The playbook. |
| `make_fixture.sh` | Builds a synthetic archive with the same layout as a real one, for testing without a registered system. |
| `README.md` | This file. |

## Requirements

- Ansible (tested with `ansible-core 2.20`)
- `insights-client` installed on the target host, for the collection step
- Root privileges (sudo) for collection, because `insights-client` must run as root
- `tar` on the target host

## How it works

1. **Collect.** Runs `insights-client --no-upload --output-file <archive>`. `--no-upload` is required: the output options only take effect without an upload, and a registered host would otherwise upload its data.
2. **Extract.** Unpacks the archive into a work directory.
3. **Locate.** Finds the archive's `data/` directory. The playbook expects exactly one and fails otherwise.
4. **Read.** Reads a short list of files from `data/` and keys them by their path relative to `data/`, so files with the same name in different directories (for example `etc/machine-id` and `etc/insights-client/machine-id`) do not collide.
5. **Publish.** Writes `/etc/ansible/facts.d/insights.fact` as JSON, then re-gathers local facts.

### Fields in the fact

| Field | Source in the archive |
| --- | --- |
| `archive` | Path of the archive that was used |
| `collected_at` | Time the playbook ran (UTC) |
| `hostname` | `data/insights_commands/hostname_-f` |
| `uname` | `data/insights_commands/uname_-a` |
| `os_release` | `data/etc/redhat-release` |
| `machine_id` | `data/etc/machine-id` |
| `insights_machine_id` | `data/etc/insights-client/machine-id` |
| `installed_packages` | `data/insights_commands/rpm_-qa_--qf_...` (one package per line, sorted) |

## Usage

Run from this directory.

**Collect a fresh archive** (needs sudo):

```bash
ansible-playbook -i localhost, insights_facts.yml -K
```

**Reuse an existing archive** (needs sudo to read a root-owned archive, but does not collect):

```bash
ansible-playbook -i localhost, insights_facts.yml -K \
  -e insights_archive_src=/var/tmp/insights-facts/insights-localhost.tar.gz
```

**Check the result:**

```bash
cat /etc/ansible/facts.d/insights.fact
ansible localhost -c local -m setup -a 'gather_subset=local filter=ansible_local'
```

### Variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `insights_become` | `true` | Run tasks with sudo. Set to `false` for testing as a normal user. |
| `insights_work_dir` | `/var/tmp/insights-facts` | Where archives and extracted files go. |
| `insights_archive_src` | `""` | Use this archive instead of collecting one. |
| `insights_facts_dir` | `/etc/ansible/facts.d` | Directory for the fact file. |
| `insights_fact_name` | `insights` | Fact name, so the result appears as `ansible_local.insights`. |
| `insights_wanted_files` | see playbook | Basenames to read from `data/`. `rpm_-qa*` is a glob. |

## Testing without a registered system

`make_fixture.sh` builds an archive with the same layout as a real one, so you can test the playbook as a normal user:

```bash
./make_fixture.sh /tmp/insights-fixture.tar.gz

ansible-playbook -i localhost, insights_facts.yml \
  -e insights_archive_src=/tmp/insights-fixture.tar.gz \
  -e insights_become=false \
  -e insights_work_dir=/tmp/insights-facts-test \
  -e insights_facts_dir=/tmp/insights-facts-test/facts.d

cat /tmp/insights-facts-test/facts.d/insights.fact
```

Example output from the fixture:

```json
{
    "archive": "/tmp/insights-facts-test/insights-localhost.tar.gz",
    "collected_at": "2026-11-04T10:20:10Z",
    "hostname": "fixture-host.example.com",
    "insights_machine_id": "11111111-2222-3333-4444-555555555555",
    "installed_packages": [
        "bash 5.2.37-1.fc44 x86_64",
        "coreutils 9.7-1.fc44 x86_64",
        "openssh 10.0p1-1.fc44 x86_64"
    ],
    "machine_id": "0123456789abcdef0123456789abcdef",
    "os_release": "Fedora release 44 (Forty Four)",
    "uname": "Linux fixture-host 7.2.15-200.fc44.x86_64 #1 SMP x86_64 GNU/Linux"
}
```

## Notes and limitations

- **Archive layout is assumed.** The file names come from the insights-core archive layout as seen on Fedora 44 with insights-client. Other versions may differ. A missing file leaves its field empty rather than failing, so check the output after a change.
- **Package list size.** `installed_packages` contains every installed package, so the fact is large on hosts with many packages.
- **Local facts are read at gather time.** Other plays see the fact only after it has been written and gathered. Plays that run before this playbook do not see it until the next gather.
- **Archives are kept.** The playbook does not delete the archive or the extracted files, so they can be inspected. They may contain sensitive host data, so remove them when you are done.
