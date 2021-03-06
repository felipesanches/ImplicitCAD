-- Implicit CAD. Copyright (C) 2011, Christopher Olah (chris@colah.ca)
-- Released under the GNU GPL, see LICENSE

module Graphics.Implicit.Export.Render.TesselateLoops (tesselateLoop) where

import Graphics.Implicit.Definitions
import Graphics.Implicit.Export.Render.Definitions
import qualified Graphics.Implicit.SaneOperators as S
import Graphics.Implicit.SaneOperators ((⋅),norm,(⨯),normalized)
import Debug.Trace

tesselateLoop :: ℝ -> Obj3 -> [[ℝ3]] -> [TriSquare]

tesselateLoop _ _ [] = []

tesselateLoop _ _ [[a,b],[_,c],[_,_]] = return $ Tris [(a,b,c)]


{-
   #____#     #____#
   |    |     |    |
   #    #  -> #____#
   |    |     |    |
   #____#     #____#
-}

tesselateLoop res obj [[_,_], as@(_:_:_:_),[_,_], bs@(_:_:_:_)] | length as == length bs =
	concat $ map (tesselateLoop res obj) $ 
		[[[a1,b1],[b1,b2],[b2,a2],[a2,a1]] | ((a1,b1),(a2,b2)) <- zip (init pairs) (tail pairs)]
			where pairs = zip (reverse as) bs

tesselateLoop res obj [as@(_:_:_:_),[_,_], bs@(_:_:_:_), [_,_] ] | length as == length bs =
	concat $ map (tesselateLoop res obj) $ 
		[[[a1,b1],[b1,b2],[b2,a2],[a2,a1]] | ((a1,b1),(a2,b2)) <- zip (init pairs) (tail pairs)]
			where pairs = zip (reverse as) bs

{-
   #__#
   |  |  -> if parallegram then quad
   #__#
-}

tesselateLoop res obj [[a,_],[b,_],[c,_],[d,_]] | (a S.+ c) == (b S.+ d) =
	let
		b1 = normalized $ a S.- b
		b2 = normalized $ c S.- b
		b3 = b1 ⨯ b2
	in [Sq (b1,b2,b3) (a ⋅ b3) (a ⋅ b1, c ⋅ b1) (a ⋅ b2, c ⋅ b2) ]

{-
   #__#      #__#
   |  |  ->  | /|
   #__#      #/_#
-}

tesselateLoop res obj [[a,_],[b,_],[c,_],[d,_]] | obj ((a S.+ c) S./ (2 :: ℝ)) < res/30 =
	return $ Tris $ [(a,b,c),(a,c,d)]

-- Fallback case: make fans

tesselateLoop res obj pathSides = return $ Tris $
	let
		path' = concat $ map init pathSides
		(early_tris,path) = shrinkLoop 0 path' res obj
	in if null path
	then early_tris
	else let
		len = fromIntegral $ length path :: ℝ
		mid@(midx,midy,midz) = (foldl1 (S.+) path) S./ len
		midval = obj mid
		preNormal = foldl1 (S.+) $
			[ a ⨯ b | (a,b) <- zip path (tail path ++ [head path]) ]
		preNormalNorm = norm preNormal
		normal = preNormal S./ preNormalNorm
		deriv = (obj (mid S.+ (normal S.* (res/100)) ) - midval)/res*100
		mid' = mid S.- normal S.* (midval/deriv)
	in if abs midval > res/50 && preNormalNorm > 0.5 && abs deriv > 0.5 
		      && abs (deriv*midval) < 1.1*res && 5*abs (obj mid') < abs midval
		then early_tris ++ [(a,b,mid') | (a,b) <- zip path (tail path ++ [head path]) ]
		else early_tris ++ [(a,b,mid) | (a,b) <- zip path (tail path ++ [head path]) ]


shrinkLoop :: Int -> [ℝ3] -> ℝ -> Obj3 -> ([Triangle], [ℝ3])

shrinkLoop _ path@[a,b,c] res obj =
	if   abs (obj ((a S.+ b S.+ c) S./ (3::ℝ) )) < res/50
	then 
		( [(a,b,c)], [])
	else 
		([], path)

shrinkLoop n path@(a:b:c:xs) res obj | n < length path =
	if abs (obj ((a S.+ c) S./ (2::ℝ) )) < res/50
	then 
		let (tris,remainder) = shrinkLoop 0 (a:c:xs) res obj
		in ((a,b,c):tris, remainder)
	else 
		shrinkLoop (n+1) (b:c:xs ++ [a]) res obj

shrinkLoop _ path _ _ = ([],path)
