package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

MOVE_SPEED :: 1
SENSITIVITY :: 1

handle_movement :: proc(cam: ^rl.Camera) {
    delta := rl.GetFrameTime()
    if rl.IsKeyDown(.W) do move_camera(cam, delta, get_forward(cam)*MOVE_SPEED)
    if rl.IsKeyDown(.A) do move_camera(cam, delta, -get_right(cam)*MOVE_SPEED)
    if rl.IsKeyDown(.S) do move_camera(cam, delta, -get_forward(cam)*MOVE_SPEED)
    if rl.IsKeyDown(.D) do move_camera(cam, delta, get_right(cam)*MOVE_SPEED)

    mouseDelta := rl.GetMouseDelta()*SENSITIVITY
    camera_yaw(cam, mouseDelta.x)
    camera_pitch(cam, mouseDelta.y)
}

get_forward :: proc(cam: ^rl.Camera) -> linalg.Vector3f32 {
    forward := cam.target-cam.position
    forward.y = 0
    return linalg.normalize(forward)
}
get_up :: proc(cam: ^rl.Camera) -> linalg.Vector3f32 {
    return linalg.normalize(cam.up)
}
get_right :: proc(cam: ^rl.Camera) -> linalg.Vector3f32 {
    right := linalg.vector_cross3(get_forward(cam), get_up(cam))
    right.y = 0
    return linalg.normalize(right)
}

move_camera :: proc (cam: ^rl.Camera, distance: f32, direction: linalg.Vector3f32) {
    cam.position += direction*distance
    cam.target += direction*distance
}

camera_yaw :: proc(cam: ^rl.Camera, angle: f32) {
    up := get_up(cam)
    target := rotate_axis_angle_f32(cam.target-cam.position, up, angle)
    cam.target = cam.position+target
}

camera_pitch :: proc (cam: ^rl.Camera, angle: f32) {
    up := get_up(cam)
    target := cam.target-cam.position

    transformedAngle := angle

    maxUp := angle_f32(up, target)-0.001
    if angle > maxUp {transformedAngle = maxUp}

    maxDown := (angle_f32(-up, target)*-1)+0.001
    if angle < maxDown {transformedAngle = maxDown}

    right := get_right(cam)
    target = rotate_axis_angle_f32(target, right, transformedAngle)
    cam.target = cam.position + target
}