package main

import "core:math/linalg"
import "core:math"

sign :: proc (i: f32) -> f32 {
    if i>0 do return 1
    if i<0 do return -1
    if i==0 do return 0
    return i
}

rotate_axis_angle_f32 :: proc(v, axis: linalg.Vector3f32, angle: f32) -> linalg.Vector3f32 { // rotate vector around an axis by an angle
    result := linalg.Vector3f32{v.x, v.y, v.z}

    length := linalg.length(axis)
    if length == 0 {length = 1.0}
    ilength := 1/length

    t := angle/2
    a := math.cos_f32(t)
    w := axis*ilength*math.sin_f32(t)

    wv := linalg.vector_cross3(w,v)
    wwv := linalg.vector_cross3(w,wv)
    wv*=2*a
    wwv*=2
    return result+wv+wwv
}

angle_f32 :: proc(v1, v2: linalg.Vector3f32) -> f32 { // the angle between two vectors, eg. an up vector and a facing vector.
    cross := linalg.vector_cross3(v1, v2)
    len := linalg.length(cross)
    dot := linalg.vector_dot(v1,v2)
    return math.atan2_f32(len,dot)
}