package main

import "core:os"
import "core:fmt"
import "core:math"
import "gameobject"
import "core:math/linalg"
import rl "vendor:raylib"

Vector3f32 :: linalg.Vector3f32

main :: proc () {   
    rl.SetConfigFlags({.WINDOW_TRANSPARENT, .WINDOW_UNDECORATED, .MSAA_4X_HINT})
    rl.InitWindow(1280,720,"Game")
    defer rl.CloseWindow()

    camera := rl.Camera {
        Vector3f32{10,10,10},
        Vector3f32{0,0,0},
        Vector3f32{0,1,0},
        90,
        .PERSPECTIVE,
    }

    defaultMaterial := rl.LoadMaterialDefault()
    rayMaterial := rl.LoadMaterialDefault()
    rayMaterial.maps[rl.MaterialMapIndex.ALBEDO].color = rl.RED
    playerMesh := rl.GenMeshCylinder(0.5,2,16)
    rayMesh := rl.GenMeshCube(0.01,0.01,0.5)
    floorMesh := rl.GenMeshCube(100,0.05,100)
    floorBB := rl.GetMeshBoundingBox(floorMesh)
    floorGameObject := gameobject.GameObject{
        floorMesh,
        defaultMaterial,
        floorBB,
        transpose(linalg.matrix4_translate(Vector3f32{0,0,0})),
    }
    playerOriginalBB := rl.GetMeshBoundingBox(playerMesh)

    objects: [dynamic]gameobject.GameObject
    append(&objects, floorGameObject)
    cubeMesh := rl.GenMeshCube(2,1,2)

    for i in 0..<1000 {
        cubeBB := rl.GetMeshBoundingBox(cubeMesh)
        cubeBB.min += Vector3f32{i%4<2?0:2,1.5*f32(i)+0.5,(i%4==0||i%4==3)?0:2}
        cubeBB.max += Vector3f32{i%4<2?0:2,1.5*f32(i)+0.5,(i%4==0||i%4==3)?0:2}
        cubeGameObject := gameobject.GameObject{
            cubeMesh,
            defaultMaterial,
            cubeBB,
            transpose(linalg.matrix4_translate(Vector3f32{i%4<2?0:2,1.5*f32(i)+0.5,(i%4==0||i%4==3)?0:2})),
        }
        append(&objects, cubeGameObject)
    }

    playerPos := Vector3f32{0,0,0}
    playerVel := Vector3f32{0,0,0}
    playerRotation := linalg.Vector4f32{}
    playerBB := playerOriginalBB

    jumping := false
    onGround := true

    rl.DisableCursor()
    defer rl.EnableCursor()
    rl.SetTargetFPS(90)
    for !rl.WindowShouldClose() {
        handle_movement(camera)
        delta := rl.GetFrameTime()

        if !onGround {
            playerVel.y -= delta
        }

        predictedPos := (camera.position+playerVel)-Vector3f32{0,1.75,0}
        predictedBB := rl.BoundingBox{playerOriginalBB.min + predictedPos, playerOriginalBB.max + predictedPos}
        notTouchingCount := len(objects)
        for object in objects { // O(n^2) sucks, but I am absolutely not prepared to implement a sweep algorithm to make it O(n log(n)) or O(log(n)+n)
            // this is actually only O(n+1), because I'm checking every object against the player
            // however if I were to add more dynamic objects other than the player this would end horribly
            // this also technically has support for rotation and OBB but that's a really complicated system
            // that requires torque and such to function properly
            // I have this in a different system but it functions weirdly to say the least
            bb := object.boundingBox
            if rl.CheckCollisionBoxes(predictedBB, bb) {
                predictedCenter := predictedBB.min + (predictedBB.max - predictedBB.min) * 0.5 // get the center of the predicted bounding box
                bbCenter := bb.min + (bb.max - bb.min) * 0.5 // get the center of the collided bounding box
                relativeCenter := bbCenter-predictedCenter // get the center between these two objects, this is most likely the point of collision
                predictedExtents := predictedBB.max-predictedBB.min // get the extents of the predicted bounding box, effectively normalize it
                bbExtents := bb.max-bb.min // get the extents of the collided bounding box
                overlap := (predictedExtents+bbExtents)-linalg.abs(relativeCenter) // get the overlap between the predicted bounding box and the collided object

                collisionNormal := linalg.normalize(relativeCenter) // get the normal of the collision point
                if (overlap.x < overlap.y && overlap.x < overlap.z) { // check which axis it was *most likely* on
                    collisionNormal = Vector3f32{sign(relativeCenter.x), 0, 0}
                } else if (overlap.y < overlap.x && overlap.y < overlap.z) {
                    collisionNormal = Vector3f32{0, sign(relativeCenter.y), 0}
                } else if (overlap.z < overlap.x && overlap.z < overlap.y) {
                    collisionNormal = Vector3f32{0, 0, sign(relativeCenter.z)}
                }

                // get correction distance so that we don't collide anymore
                collisionDistanceX := math.abs(predictedCenter.x - bbCenter.x) - (predictedExtents.x + bbExtents.x)
                collisionDistanceY := math.abs(predictedCenter.y - bbCenter.y) - (predictedExtents.y + bbExtents.y)
                collisionDistanceZ := math.abs(predictedCenter.z - bbCenter.z) - (predictedExtents.z + bbExtents.z)

                collisionDistance := math.min(collisionDistanceX, collisionDistanceY, collisionDistanceZ)

                if collisionNormal.y > 0.9 || collisionNormal.y < -0.9 { // this implies we've hit the ground OR a roof, kinda wacky.
                    jumping = false
                    onGround = true
                }

                collisionNormal = linalg.normalize(collisionNormal)
                playerVel -= linalg.dot(playerVel, collisionNormal) * collisionNormal
                
                penetrationThreshold :: 0.01
                penetrationDepth :f32= math.max(0,collisionDistance)
                if penetrationDepth > penetrationThreshold {
                    playerVel = playerVel + collisionNormal * (penetrationDepth - penetrationThreshold)
                }                
            } else {
                notTouchingCount -= 1
            }
        }
        onGround = notTouchingCount > 0

        camera.position += playerVel
        camera.target += playerVel
        if camera.position.y <= -50 do camera.position.y = 50
        if camera.target.y <= -50 do camera.target.y = 50
        playerPos = camera.position-Vector3f32{0,1.75,0}
        playerBB.min = playerOriginalBB.min+playerPos
        playerBB.max = playerOriginalBB.max+playerPos

        // simulate friction, air resistance, etc without doing expensive calculations
        // I could add a whole friction system to my game, and read up on all the math 
        // required to calculate the drag of a cylinder, but that's stupid, and expensive,
        // and would require some stupid math I've read a thousand times before.
        playerVel.x *= 0.5*delta
        playerVel.z *= 0.5*delta

        direction := linalg.normalize(camera.target - camera.position)
        angle := math.atan2(direction.x, direction.z)

        rl.BeginDrawing()
            rl.ClearBackground(rl.Color{69,69,69,255})
            rl.BeginMode3D(camera)
                for object in objects do gameobject.draw(object)
                rl.DrawMesh(rayMesh, rayMaterial, transpose(linalg.matrix4_translate(playerPos+Vector3f32{0,1.75,0})*linalg.matrix4_rotate(angle,Vector3f32{0,1,0})*linalg.matrix4_translate(Vector3f32{0,0,0.75})))
                rl.DrawMesh(playerMesh, defaultMaterial, transpose(linalg.matrix4_translate(playerPos)*linalg.matrix4_rotate(angle, Vector3f32{0,1,0})))
                rl.DrawBoundingBox(playerBB, rl.GREEN)
                rl.DrawBoundingBox(predictedBB, rl.BLUE)
                rl.DrawGrid(100,1)
            rl.EndMode3D()
            rl.DrawFPS(15,15)
            rl.DrawText(rl.TextFormat("Coordinates: X:%f Y:%f Z:%f", playerPos.x, playerPos.y, playerPos.z), 15, 35, 20, rl.GREEN)
            rl.DrawText(rl.TextFormat("Velocity: X:%f Y:%f Z:%f", playerVel.x, playerVel.y, playerVel.z), 15, 55, 20, rl.GREEN)
            rl.DrawText(rl.TextFormat("OnGround: %s", onGround ? "true" : "false" ), 15, 75, 20, rl.GREEN)
        rl.EndDrawing()
    }
}