#!/usr/bin/env python3
"""Demo B publisher (ROS 2 -> ROS 1 via parameter_bridge).

Long-lived rclpy node with a Timer. Replaces the previous
bash + ros2 topic pub --once pattern (PR #93 / #94):
single rclpy init at startup so the achievable rate is
the requested one, not floored at ~1.5 Hz by per-iteration
rclpy spinup. Counter lives in the Python process so each
message is distinguishable on the wire (#1, #2, ...).
"""

import argparse
import sys

import rclpy
from rclpy.node import Node
from std_msgs.msg import String


class DemoPub(Node):
    def __init__(self, topic: str, message: str, rate: float) -> None:
        super().__init__("demo_pub_ros2")
        self._pub = self.create_publisher(String, topic, 10)
        self._message = message
        self._seq = 0
        self._timer = self.create_timer(1.0 / rate, self._tick)

    def _tick(self) -> None:
        self._seq += 1
        payload = "{} #{}".format(self._message, self._seq)
        print("[demo_pub_ros2] publishing {}".format(payload), flush=True)
        msg = String()
        msg.data = payload
        self._pub.publish(msg)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--topic", required=True,
                        help="ROS topic to publish on")
    parser.add_argument("--message", default="hello from ROS 2",
                        help='Base message text; "#N" counter appended.'
                             ' Default: "hello from ROS 2"')
    parser.add_argument("--rate", type=float, default=10.0,
                        help="Publish rate in Hz. Default: 10")
    args = parser.parse_args()

    rclpy.init()
    node = DemoPub(args.topic, args.message, args.rate)
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()
    return 0


if __name__ == "__main__":
    sys.exit(main())
