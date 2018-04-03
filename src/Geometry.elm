module Geometry exposing (..)

import Basics.Extra exposing (fmod)
import WebGL exposing (Mesh)
import Math.Matrix4 as Mat4 exposing (Mat4, transform, translate, rotate)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Munsell exposing (ColorDict, findColor)


{-| Coordinate system:
z is up, x coming out towards camera, y to right
-}
worldUp : Vec3
worldUp =
    vec3 0 0 1


worldCenter : Vec3
worldCenter =
    vec3 0 0 0


minusK : Vec3
minusK =
    vec3 0 0 -1



---- WEBGL TYPES ----


type alias Color =
    Vec3


type alias Vertex =
    { position : Vec3
    , color : Color
    }


type alias AppMesh =
    Mesh Vertex


type alias Camera =
    { position : Vec3
    , phi : Float
    }


makeCamera : Float -> Float -> Float -> Camera
makeCamera cameraDistance theta phi =
    { position =
        vec3
            (cameraDistance * sin theta * cos phi)
            (cameraDistance * sin theta * sin phi)
            (cameraDistance * cos theta)
    , phi = fmod phi (2 * pi)
    }


dragCamera : Float -> Float -> Float -> Camera -> Camera
dragCamera cameraDistance deltaX deltaY { position, phi } =
    let
        radPerPixel =
            pi / cameraDistance

        deltaPhi =
            radPerPixel * deltaX

        deltaTheta =
            radPerPixel * deltaY

        normal =
            Vec3.normalize position

        -- Subtract deltaTheta and deltaPhi
        theta =
            (acos (Vec3.getZ normal))
                - deltaTheta
                |> (Basics.max 0)
                |> (Basics.min pi)
    in
        makeCamera cameraDistance theta (phi - deltaPhi)


cameraMatrix : Camera -> Mat4
cameraMatrix { position, phi } =
    let
        cameraDistance =
            Vec3.length position

        normal =
            Vec3.normalize position

        dot =
            Vec3.dot normal Vec3.k
    in
        case dot > 0.99999 of
            True ->
                Mat4.fromRecord
                    { m11 = 0
                    , m21 = -1
                    , m31 = 0
                    , m41 = 0
                    , m12 = 1
                    , m22 = 0
                    , m32 = 0
                    , m42 = 0
                    , m13 = 0
                    , m23 = 0
                    , m33 = 1
                    , m43 = 0
                    , m14 = 0
                    , m24 = 0
                    , m34 = -cameraDistance
                    , m44 = 1
                    }
                    |> Mat4.rotate -phi Vec3.k

            False ->
                case dot < -0.99999 of
                    True ->
                        Mat4.fromRecord
                            { m11 = 0
                            , m21 = 1
                            , m31 = 0
                            , m41 = 0
                            , m12 = 1
                            , m22 = 0
                            , m32 = 0
                            , m42 = 0
                            , m13 = 0
                            , m23 = 0
                            , m33 = -1
                            , m43 = 0
                            , m14 = 0
                            , m24 = 0
                            , m34 = -cameraDistance
                            , m44 = 1
                            }
                            |> Mat4.rotate -phi Vec3.k

                    False ->
                        Mat4.makeLookAt position worldCenter worldUp


type alias Uniforms =
    { perspective : Mat4
    , camera : Mat4
    }


makeUniforms : Float -> Float -> Float -> Camera -> Uniforms
makeUniforms width height worldSize camera =
    { perspective = Mat4.makePerspective 22 (width / height) 0.01 (worldSize * 4)
    , camera = cameraMatrix camera
    }


{-| A GeometryObject is made up of vertices.
A Cube has 4 corner points (top face) and 4 on the bottom face = 8 total.
A Cylinder has 1 center point plus 'cylinderFacePoints' on the circumference
of both the top and bottom faces.
-}
type ObjectType
    = Cube
    | Cylinder
    | Polyline


type alias GeometryObject =
    { type_ : ObjectType
    , vertices : List Vertex
    }


getVertices : GeometryObject -> List Vertex
getVertices { vertices } =
    vertices


getVertexIndices : Int -> GeometryObject -> List ( Int, Int, Int )
getVertexIndices base { type_, vertices } =
    case type_ of
        Cube ->
            cubeIndices base

        Cylinder ->
            cylinderIndices base

        _ ->
            []



---- COLORS ----


type alias BallColors =
    { xPos : Color
    , xNeg : Color
    , yPos : Color
    , yNeg : Color
    , oPos : Color
    , oNeg : Color
    }


defaultBallColors : BallColors
defaultBallColors =
    { xPos = vec3 1 0 0
    , xNeg = vec3 0 1 0
    , yPos = vec3 1 1 0
    , yNeg = vec3 0 1 1
    , oPos = vec3 0 0 1
    , oNeg = vec3 1 0 1
    }


makeColor : ColorDict -> Int -> Int -> Int -> Maybe Color
makeColor colors hue value chroma =
    case findColor colors hue value chroma of
        Ok mc ->
            Just <| vec3 mc.red mc.green mc.blue

        Err err ->
            Nothing



---- INDEXED TRIANGLE OBJECTS ----


indexedTriangleMesh : List GeometryObject -> AppMesh
indexedTriangleMesh objects =
    let
        ( v, i ) =
            buildTriangleIndices objects
    in
        WebGL.indexedTriangles v i


buildTriangleIndices : List GeometryObject -> ( List Vertex, List ( Int, Int, Int ) )
buildTriangleIndices objects =
    List.foldl
        (\object ( accv, acci ) ->
            case object.type_ of
                Polyline ->
                    ( accv, acci )

                _ ->
                    let
                        base =
                            List.length accv
                    in
                        ( List.append accv (getVertices object)
                        , List.append acci (getVertexIndices base object)
                        )
        )
        ( [], [] )
        objects



---- CYLINDERS ----


cylinderFacePoints : Int
cylinderFacePoints =
    16


cylinderPoints : Int
cylinderPoints =
    2 * (cylinderFacePoints + 1)


cylinderFaceVertex : Color -> Mat4 -> Float -> Int -> Vertex
cylinderFaceVertex color xf z i =
    let
        t =
            pi * (toFloat ((i - 1) * 2)) / (toFloat cylinderFacePoints)
    in
        Vertex (transform xf (vec3 (0.5 * sin t) (0.5 * cos t) z)) color


makeCylinder : Color -> Mat4 -> GeometryObject
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
            |> GeometryObject Cylinder


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


cubePoints : Int
cubePoints =
    8


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


makeCube : Color -> Mat4 -> GeometryObject
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
        |> GeometryObject Cube


cubeIndices : Int -> List ( Int, Int, Int )
cubeIndices base =
    cubeVertexOrder
        |> List.map
            (\( v1, v2, v3 ) ->
                ( base + v1, base + v2, base + v3 )
            )



---- POLYLINE OBJECTS ----


polylineMeshes : List GeometryObject -> List AppMesh
polylineMeshes objects =
    List.foldl
        (\object acc ->
            case object.type_ of
                Polyline ->
                    WebGL.lineStrip (getVertices object) :: acc

                _ ->
                    acc
        )
        []
        objects


makeWireframeBall : BallColors -> Mat4 -> List GeometryObject
makeWireframeBall colors xf =
    equator colors.xPos colors.xNeg xf
        :: segment colors.yPos colors.yNeg 0 xf
        :: (List.range 1 ((cylinderFacePoints // 2) - 1)
                |> List.map
                    (\i ->
                        let
                            angle =
                                (toFloat i) * 2 * pi / (toFloat cylinderFacePoints)
                        in
                            segment colors.oPos colors.oNeg angle xf
                    )
           )
        |> List.concat


equator : Color -> Color -> Mat4 -> List GeometryObject
equator colorPos colorNeg xf =
    let
        posHalf =
            List.range 0 (cylinderFacePoints // 2)
                |> List.map
                    (\i ->
                        let
                            theta =
                                (toFloat i) * 2 * pi / (toFloat cylinderFacePoints)
                        in
                            Vertex (transform xf (vec3 (0.5 * sin theta) (0.5 * cos theta) 0)) colorPos
                    )
                |> GeometryObject Polyline

        negHalf =
            List.range (cylinderFacePoints // 2) cylinderFacePoints
                |> List.map
                    (\i ->
                        let
                            theta =
                                (toFloat i) * 2 * pi / (toFloat cylinderFacePoints)
                        in
                            Vertex (transform xf (vec3 (0.5 * sin theta) (0.5 * cos theta) 0)) colorNeg
                    )
                |> GeometryObject Polyline
    in
        [ posHalf, negHalf ]


segment : Color -> Color -> Float -> Mat4 -> List GeometryObject
segment colorPos colorNeg angle xf =
    let
        posHalf =
            List.range 0 (cylinderFacePoints // 2)
                |> List.map
                    (\i ->
                        let
                            theta =
                                (toFloat i) * 2 * pi / (toFloat cylinderFacePoints)

                            xf_ =
                                Mat4.rotate angle (vec3 0 0 1) xf
                        in
                            Vertex (transform xf_ (vec3 (0.5 * cos theta) 0 (0.5 * sin theta))) colorPos
                    )
                |> GeometryObject Polyline

        negHalf =
            List.range (cylinderFacePoints // 2) cylinderFacePoints
                |> List.map
                    (\i ->
                        let
                            theta =
                                (toFloat i) * 2 * pi / (toFloat cylinderFacePoints)

                            xf_ =
                                Mat4.rotate angle (vec3 0 0 1) xf
                        in
                            Vertex (transform xf_ (vec3 (0.5 * cos theta) 0 (0.5 * sin theta))) colorNeg
                    )
                |> GeometryObject Polyline
    in
        [ posHalf, negHalf ]
