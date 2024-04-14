
interface buspirate

buspirate_port $DEBUGDUE_SERIAL_PORT

buspirate_speed   fast  # No effect with the DebugDue firmware.

buspirate_vreg    0     # No effect with the DebugDue firmware.

buspirate_pullup  0     # The target (second) Arduino Due already has pull-ups on its JTAG interface.

# Given the weak pull-ups on both:
# - the Arduino Due acting as a JTAG adapter (running the DebugDue firmware), and
# - the target (second) Arduino Due
# it is best to use the "normal" mode here:
buspirate_mode normal  # 'normal' or 'open-drain'.
