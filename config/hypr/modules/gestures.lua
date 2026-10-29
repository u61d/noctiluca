hl.config({
  gestures = {
    workspace_swipe_distance = 300,
    workspace_swipe_cancel_ratio = 0.2,
    workspace_swipe_min_speed_to_force = 30,
  },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
