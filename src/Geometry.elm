module Geometry
    exposing
        ( Color
        , Vertex
        , AppMesh
        , Uniforms
        , Cube
        , Cylinder
        , cubePoints
        , cylinderPoints
        , makeColor
        , makeCylinder
        , makeCube
        , cylinderIndices
        , cubeIndices
        , cubesIndices
        )

import WebGL exposing (Mesh)
import Math.Matrix4 as Mat4 exposing (Mat4, transform, translate, rotate)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Munsell exposing (ColorDict, findColor)


---- WEBGL TYPES ----


type alias Color =
    Vec3


type alias Vertex =
    { position : Vec3
    , color : Color
    }


type alias AppMesh =
    Mesh Vertex


type alias Uniforms =
    { perspective : Mat4 }


{-| List of 4 corner points (top face) * 2
List.length cube == 2 * 4
-}
type alias Cube =
    List Vertex


{-| List of center point and 'cylinderFacePoints' points on circumference (top face) * 2
List.length cylinder = 2 * (cylinderFacePoints + 1)
-}
type alias Cylinder =
    List Vertex



---- CONSTANTS ----


cubePoints : Int
cubePoints =
    8


cylinderFacePoints : Int
cylinderFacePoints =
    30


cylinderPoints : Int
cylinderPoints =
    2 * (cylinderFacePoints + 1)


cubeVertexOrder : List ( Int, Int, Int )
cubeVertexOrder =
    [ -- front
      ( 0, 1, 2 )
    , ( 2, 3, 0 )
    , -- right
      ( 1, 5, 6 )
    , ( 6, 2, 1 )
    , -- back
      ( 7, 6, 5 )
    , ( 5, 4, 7 )
    , -- left
      ( 4, 0, 3 )
    , ( 3, 7, 4 )
    , -- bottom
      ( 4, 5, 1 )
    , ( 1, 0, 4 )
    , -- top
      ( 3, 2, 6 )
    , ( 6, 7, 3 )
    ]



---- COLORS ----


makeColor : ColorDict -> Int -> Int -> Int -> Maybe Color
makeColor colors hue value chroma =
    case findColor colors hue value chroma of
        Ok mc ->
            Just <| vec3 mc.red mc.green mc.blue

        Err err ->
            Nothing



---- CYLINDERS ----


cylinderFaceVertex : Color -> Mat4 -> Float -> Int -> Vertex
cylinderFaceVertex color xf z i =
    let
        t =
            Basics.pi * toFloat i * (2.0 / toFloat cylinderFacePoints)
    in
        Vertex (transform xf (vec3 (sin t) (cos t) z)) color


makeCylinder : Color -> Mat4 -> Cylinder
makeCylinder color xf =
    let
        topFace =
            List.range 1 cylinderFacePoints
                |> List.map (cylinderFaceVertex color xf 0.5)

        bottomFace =
            List.range 1 cylinderFacePoints
                |> List.map (cylinderFaceVertex color xf -0.5)
    in
        List.concat
            [ Vertex (transform xf (vec3 0 0 0.5)) color :: topFace
            , Vertex (transform xf (vec3 0 0 -0.5)) color :: bottomFace
            ]


cylinderIndices : Int -> List ( Int, Int, Int )
cylinderIndices base =
    let
        top =
            List.range 1 cylinderFacePoints
                |> List.map
                    (\i ->
                        ( base
                        , base + i
                        , if i < cylinderFacePoints then
                            base + i + 1
                          else
                            base + 1
                        )
                    )

        sides =
            List.range 1 cylinderFacePoints
                |> List.map
                    (\i ->
                        if i < cylinderFacePoints then
                            [ ( base + i
                              , base + i + cylinderFacePoints + 1
                              , base + i + cylinderFacePoints + 2
                              )
                            , ( base + i + cylinderFacePoints + 2
                              , base + i + 1
                              , base + i
                              )
                            ]
                        else
                            [ ( base + cylinderFacePoints
                              , base + 2 * cylinderFacePoints + 1
                              , base + cylinderFacePoints + 2
                              )
                            , ( base + cylinderFacePoints + 2
                              , base + 1
                              , base + cylinderFacePoints
                              )
                            ]
                    )
                |> List.concat

        bottom =
            List.range (cylinderFacePoints + 1) (2 * cylinderFacePoints + 1)
                |> List.reverse
                |> List.map
                    (\i ->
                        ( base + cylinderFacePoints + 1
                        , base + i
                        , if i > cylinderFacePoints then
                            base + i - 1
                          else
                            base + 2 * cylinderFacePoints + 1
                        )
                    )
    in
        List.concat [ top, sides, bottom ]



---- CUBES ----


makeCube : Color -> Mat4 -> Cube
makeCube color xf =
    [ Vertex (transform xf (vec3 -0.5 -0.5 0.5)) color
    , Vertex (transform xf (vec3 -0.5 0.5 0.5)) color
    , Vertex (transform xf (vec3 0.5 0.5 0.5)) color
    , Vertex (transform xf (vec3 0.5 -0.5 0.5)) color
    , Vertex (transform xf (vec3 -0.5 -0.5 -0.5)) color
    , Vertex (transform xf (vec3 -0.5 0.5 -0.5)) color
    , Vertex (transform xf (vec3 0.5 0.5 -0.5)) color
    , Vertex (transform xf (vec3 0.5 -0.5 -0.5)) color
    ]


cubeIndices : Int -> List ( Int, Int, Int )
cubeIndices base =
    cubeVertexOrder
        |> List.map
            (\( v1, v2, v3 ) ->
                ( base + v1, base + v2, base + v3 )
            )


cubesIndices : Int -> List Cube -> List ( Int, Int, Int )
cubesIndices offset cubes =
    List.indexedMap (\i _ -> cubeIndices (cubePoints * i + offset)) cubes
        |> List.concat
