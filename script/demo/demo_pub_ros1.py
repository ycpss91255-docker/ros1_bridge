#!/usr/bin/env python3
"""Demo A publisher (ROS 1 -> ROS 2 via parameter_bridge).

Long-lived rospy.Publisher loop. Replaces the previous
bash + rostopic pub --once pattern (PR #93 / #94):
single rospy init at startup so the achievable rate is
the requested one, not floored at ~1.5 Hz by per-iteration
rospy spinup. Counter lives in the Python process so each
message is distinguishable on the wire (#1, #2, ...).
"""

import argparse
import sys

import rospy
from std_msgs.msg import String


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--topic", required=True,
                        help="ROS topic to publish on")
    parser.add_argument("--message", default="hello from ROS 1",
                        help='Base message text; "#N" counter appended.'
                             ' Default: "hello from ROS 1"')
    parser.add_argument("--rate", type=float, default=10.0,
                        help="Publish rate in Hz. Default: 10")
    args = parser.parse_args()

    rospy.init_node("demo_pub_ros1", anonymous=True)
    pub = rospy.Publisher(args.topic, String, queue_size=10, latch=True)
    rate = rospy.Rate(args.rate)

    seq = 0
    while not rospy.is_shutdown():
        seq += 1
        payload = "{} #{}".format(args.message, seq)
        print("[demo_pub_ros1] publishing {}".format(payload), flush=True)
        pub.publish(payload)
        rate.sleep()
    return 0


if __name__ == "__main__":
    sys.exit(main())
