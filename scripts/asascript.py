from genie.testbed import load
from unicon.core.errors import StateMachineError
import json
from jsonmerge import merge

tb = load("/opt/telegraf/ASA-Telemetry-Guide/telegraf/scripts/testbed-asa.yaml")
results = []

for name, dev in tb.devices.items():
    try:
        dev.connect(learn_hostname=True, init_exec_commands=[], init_config_commands=[], log_stdout=False)
        try:
            dev.state_machine.go_to("enable", dev.spawn, context=dev, timeout=30)
        except StateMachineError:
            pass
        dev.execute("terminal pager 0")
        out = {"switch_name": name}
        try:
            p1 = dev.parse("show vpn-sessiondb")
            out = merge(out, p1)
        except Exception as e:
            out["vpn_sessiondb_error"] = str(e)
        try:
            p2 = dev.parse("show resource usage")
            out = merge(out, p2)
        except Exception as e:
            out["resource_usage_error"] = str(e)
        results.append(out)
        dev.disconnect()
    except Exception as e:
        results.append({"switch_name": name, "connection_error": str(e)})

print(json.dumps(results))
