from genie.testbed import load
from unicon.eal.dialogs import Dialog, Statement
from unicon.core.errors import StateMachineError
import json
import os
from jsonmerge import merge

os.chdir("/tmp")

tb = load("/opt/telegraf/ASA-Telemetry-Guide/telegraf/scripts/testbed-asa.yaml")

results = []
for name, dev in tb.devices.items():
    dev.connect(learn_hostname=True, init_exec_commands=[], init_config_commands=[], log_stdout=False)

    dlg = Dialog([Statement(pattern=r"(?i)^Password:\s*$", action="sendline()", loop_continue=True, continue_timer=False)])

    try:
        dev.state_machine.go_to("enable", dev.spawn, context=dev, timeout=30, dialog=dlg)
    except StateMachineError:
        pass

    dev.execute("terminal pager 0")

    p1 = dev.parse("show vpn-sessiondb")
    p2 = dev.parse("show resource usage")
    results.append(merge({"switch_name": name}, merge(p1, p2)))

print(json.dumps(results))
