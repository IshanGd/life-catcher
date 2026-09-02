#!/usr/bin/env python3
"""Desktop BLE bring-up client for the Smart Helmet prototype.

Connects to the helmet, prints STATUS and EVENT notifications as they arrive,
and lets you send the app-side commands (cancel / ack) from the keyboard.
This stands in for the companion app during Phase 2 hardware bring-up.

    pip install bleak
    python ble_probe.py            # scan + connect to the first SmartHelmet-*
    python ble_probe.py --address AA:BB:CC:DD:EE:FF

Keys while running:  c = send cancel   a = send ack   q = quit
"""
from __future__ import annotations

import argparse
import asyncio
import sys

try:
    from bleak import BleakClient, BleakScanner
except ImportError:
    sys.exit("pip install bleak")

SVC   = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
STATUS = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
EVENT  = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
CMD    = "6e400004-b5a3-f393-e0a9-e50e24dcca9e"


def _on_status(_h, data: bytearray) -> None:
    print(f"  STATUS  {data.decode(errors='replace')}")


def _on_event(_h, data: bytearray) -> None:
    print(f"* EVENT   {data.decode(errors='replace')}")


async def _find(address: str | None) -> str:
    if address:
        return address
    print("scanning 8 s for SmartHelmet-* ...")
    devs = await BleakScanner.discover(timeout=8.0)
    for d in devs:
        if (d.name or "").startswith("SmartHelmet"):
            print(f"found {d.name} @ {d.address}")
            return d.address
    sys.exit("no SmartHelmet-* advertised. Is it powered and in range?")


async def _stdin_commands(client: BleakClient) -> None:
    loop = asyncio.get_event_loop()
    while True:
        key = (await loop.run_in_executor(None, sys.stdin.readline)).strip().lower()
        if key == "q":
            return
        if key == "c":
            await client.write_gatt_char(CMD, b'{"cmd":"cancel"}', response=True)
            print("  -> sent cancel")
        elif key == "a":
            await client.write_gatt_char(CMD, b'{"cmd":"ack"}', response=True)
            print("  -> sent ack")


async def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--address")
    args = ap.parse_args()

    address = await _find(args.address)
    async with BleakClient(address) as client:
        print(f"connected: {client.is_connected}")
        await client.start_notify(STATUS, _on_status)
        await client.start_notify(EVENT, _on_event)
        print("streaming. keys: c=cancel  a=ack  q=quit")
        try:
            await _stdin_commands(client)
        finally:
            await client.stop_notify(STATUS)
            await client.stop_notify(EVENT)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
