module Tests exposing (..)

import Math.Vector3 as Vec3 exposing (vec3)
import Math.Matrix4 as Mat4
import Geometry as Geom exposing (..)
import ColorWheel exposing (..)
import Test exposing (..)
import Expect exposing (FloatingPointTolerance(..))


-- Check out http://package.elm-lang.org/packages/elm-community/elm-test/latest to learn more about testing in Elm!


cameraTest : Test
cameraTest =
    describe "Camera and perspective"
        [ test "lookAt near z-minus" <|
            \_ ->
                let
                    eye =
                        eyeCoordinates 5240 (pi * 0.99) 0
                            |> Debug.log "eye near z-minus"

                    camera =
                        Mat4.makeLookAt eye worldCenter worldUp
                            |> Debug.log "lookAt near z-minus"
                in
                    Expect.equal camera Mat4.identity
        , test "lookAt z-minus" <|
            \_ ->
                let
                    eye =
                        vec3 0 0 -5240
                            |> Debug.log "eye z-minus"

                    camera =
                        Mat4.makeLookAt eye worldCenter worldUp
                            |> Debug.log "lookAt z-minus"
                in
                    Expect.equal camera Mat4.identity
        , test "lookAt near z-plus" <|
            \_ ->
                let
                    eye =
                        eyeCoordinates 5240 (pi * 0.01) 0
                            |> Debug.log "eye near z-plus"

                    camera =
                        Mat4.makeLookAt eye worldCenter worldUp
                            |> Debug.log "lookAt near z-plus"
                in
                    Expect.equal camera Mat4.identity
        , test "lookAt z-plus" <|
            \_ ->
                let
                    eye =
                        vec3 0 0 5240
                            |> Debug.log "eye z-plus"

                    camera =
                        Mat4.makeLookAt eye worldCenter worldUp
                            |> Debug.log "lookAt z-plus"
                in
                    Expect.equal camera Mat4.identity
        ]


cylTest : Test
cylTest =
    describe "Cylinder vertex position"
        [ test "cylinderForValue 1 [vertex 4] x" <|
            \_ ->
                let
                    ( x, y, z ) =
                        cylinderForValue 1
                            |> getVertices
                            |> List.drop (1 + (cylinderFacePoints // 4))
                            |> List.head
                            |> Maybe.withDefault (Vertex (vec3 -1 -1 -1) (vec3 -1 -1 -1))
                            |> .position
                            |> Vec3.toTuple
                in
                    Expect.within (Absolute 0.001) x (cylinderSize / 2)
        , test "cylinderForValue 1 [4] y" <|
            \_ ->
                let
                    ( x, y, z ) =
                        cylinderForValue 1
                            |> getVertices
                            |> List.drop (1 + (cylinderFacePoints // 4))
                            |> List.head
                            |> Maybe.withDefault (Vertex (vec3 -1 -1 -1) (vec3 -1 -1 -1))
                            |> .position
                            |> Vec3.toTuple
                in
                    Expect.within (Absolute 0.001) y 0
        , test "cylinderForValue 1 [vertex 4] z" <|
            \_ ->
                let
                    ( x, y, z ) =
                        cylinderForValue 1
                            |> getVertices
                            |> List.drop (1 + (cylinderFacePoints // 4))
                            |> List.head
                            |> Maybe.withDefault (Vertex (vec3 -1 -1 -1) (vec3 -1 -1 -1))
                            |> .position
                            |> Vec3.toTuple
                in
                    Expect.within (Absolute 0.001) z ((cubeSize / 2) + (4 * zSpacing))
        ]


cubeTest : Test
cubeTest =
    describe "Cube vertex position"
        [ test "cubeWithColor black 0 4 10 [vertex 0] x" <|
            \_ ->
                let
                    black =
                        vec3 0 0 0

                    ( x, y, z ) =
                        cubeWithColor black 0 4 10
                            |> getVertices
                            |> List.head
                            |> Maybe.withDefault (Vertex (vec3 -1 -1 -1) (vec3 -1 -1 -1))
                            |> .position
                            |> Vec3.toTuple
                in
                    Expect.within (Absolute 0.001) x (-cubeSize / 2)
        , test "cubeWithColor black 0 4 10 [vertex 0] y" <|
            \_ ->
                let
                    black =
                        vec3 0 0 0

                    ( x, y, z ) =
                        cubeWithColor black 0 4 10
                            |> getVertices
                            |> List.head
                            |> Maybe.withDefault (Vertex (vec3 -1 -1 -1) (vec3 -1 -1 -1))
                            |> .position
                            |> Vec3.toTuple
                in
                    Expect.within (Absolute 0.001) y (r0 + (4 * rSpacing) - (cubeSize / 2))
        , test "cubeWithColor black 0 4 10 [vertex 0] z" <|
            \_ ->
                let
                    black =
                        vec3 0 0 0

                    ( x, y, z ) =
                        cubeWithColor black 0 4 10
                            |> getVertices
                            |> List.head
                            |> Maybe.withDefault (Vertex (vec3 -1 -1 -1) (vec3 -1 -1 -1))
                            |> .position
                            |> Vec3.toTuple
                in
                    Expect.within (Absolute 0.001) z ((cubeSize / 2) + zSpacing)
        , test "cubeWithColor black 125 4 10 [vertex 0] x" <|
            \_ ->
                let
                    sqrt2 =
                        sin (pi / 4)

                    black =
                        vec3 0 0 0

                    ( x, y, z ) =
                        cubeWithColor black 125 4 10
                            |> getVertices
                            |> List.head
                            |> Maybe.withDefault (Vertex (vec3 -1 -1 -1) (vec3 -1 -1 -1))
                            |> .position
                            |> Vec3.toTuple
                in
                    Expect.within (Absolute 0.001) x ((250 - 20) * sqrt2)
        , test "cubeWithColor black 125 4 10 [vertex 0] y" <|
            \_ ->
                let
                    sqrt2 =
                        sin (pi / 4)

                    black =
                        vec3 0 0 0

                    ( x, y, z ) =
                        cubeWithColor black 125 4 10
                            |> getVertices
                            |> List.head
                            |> Maybe.withDefault (Vertex (vec3 -1 -1 -1) (vec3 -1 -1 -1))
                            |> .position
                            |> Vec3.toTuple
                in
                    Expect.within (Absolute 0.001) y ((250 + 20) * sqrt2)
        , test "cubeWithColor black 125 4 10 [vertex 0] z" <|
            \_ ->
                let
                    black =
                        vec3 0 0 0

                    ( x, y, z ) =
                        cubeWithColor black 125 4 10
                            |> getVertices
                            |> List.head
                            |> Maybe.withDefault (Vertex (vec3 -1 -1 -1) (vec3 -1 -1 -1))
                            |> .position
                            |> Vec3.toTuple
                in
                    Expect.within (Absolute 0.001) z ((cubeSize / 2) + zSpacing)
        ]
