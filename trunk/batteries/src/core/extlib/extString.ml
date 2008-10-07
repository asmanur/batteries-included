(*
 * ExtString - Additional functions for string manipulations.
 * Copyright (C) 2003 Nicolas Cannasse
 *               2008 David Teller
 *               2008 Edgar Friendly
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version,
 * with the special exception on linking described in file LICENSE.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *)

open Sexplib
open Conv
TYPE_CONV_PATH "Batteries.Data.Text" (*For Sexplib, Bin-prot...*)

exception Invalid_string

module String = struct

exception Invalid_string = Invalid_string

include String

let sexp_of_t = sexp_of_string
let t_of_sexp = string_of_sexp

let init len f =
	let s = create len in
	for i = 0 to len - 1 do
		unsafe_set s i (f i)
	done;
	s

let starts_with str p =
	let len = length p in
	if length str < len then 
		false
	else
		sub str 0 len = p

let ends_with s e =
	let el = length e in
	let sl = length s in
	if sl < el then
		false
	else
		sub s (sl-el) el = e

let find str sub =
	let sublen = length sub in
	if sublen = 0 then
		0
	else
		let found = ref 0 in
		let len = length str in
		try
			for i = 0 to len - sublen do
				let j = ref 0 in
				while unsafe_get str (i + !j) = unsafe_get sub !j do
					incr j;
					if !j = sublen then begin found := i; raise Exit; end;
				done;
			done;
			raise Invalid_string
		with
			Exit -> !found

let exists str sub =
	try
		ignore(find str sub);
		true
	with
		Invalid_string -> false

let strip ?(chars=" \t\r\n") s =
	let p = ref 0 in
	let l = length s in
	while !p < l && contains chars (unsafe_get s !p) do
		incr p;
	done;
	let p = !p in
	let l = ref (l - 1) in
	while !l >= p && contains chars (unsafe_get s !l) do
		decr l;
	done;
	sub s p (!l - p + 1)

let split str sep =
	let p = find str sep in
	let len = length sep in
	let slen = length str in
	sub str 0 p, sub str (p + len) (slen - p - len)

let nsplit str sep =
	if str = "" then []
	else (
		let rec nsplit str sep =
			try
				let s1 , s2 = split str sep in
				s1 :: nsplit s2 sep
			with
				Invalid_string -> [str]
		in
		nsplit str sep
	)

let join = concat

let slice ?(first=0) ?(last=Sys.max_string_length) s =
	let clip _min _max x = max _min (min _max x) in
	let i = clip 0 (length s)
		(if (first<0) then (length s) + first else first)
	and j = clip 0 (length s)
		(if (last<0) then (length s) + last else last)
	in
	if i>=j || i=length s then
		create 0
        else
          	sub s i (j-i)

let lchop s =
	if s = "" then "" else sub s 1 (length s - 1)

let rchop s =
	if s = "" then "" else sub s 0 (length s - 1)

let of_int = string_of_int

let of_float = string_of_float

let of_char = make 1

let to_int s =
	try
		int_of_string s
	with
		_ -> raise Invalid_string

let to_float s =
	try
		float_of_string s
	with
		_ -> raise Invalid_string

let enum s =
	let l = length s in
	let rec make i =
		Enum.make 
		~next:(fun () ->
			if !i = l then
				raise Enum.No_more_elements
			else
				let p = !i in
				incr i;
				unsafe_get s p
			)
		~count:(fun () -> l - !i)
		~clone:(fun () -> make (ref !i))
	in
	make (ref 0)

let of_enum e =
	let l = Enum.count e in
	let s = create l in
	let i = ref 0 in
	Enum.iter (fun c -> unsafe_set s !i c; incr i) e;
	s


let map f s =
	let len = length s in
	let sc = create len in
	for i = 0 to len - 1 do
		unsafe_set sc i (f (unsafe_get s i))
	done;
	sc

let filter_map f s =
  let len = length s          in
  let sc  = Buffer.create len in
    for i = 0 to len - 1 do
      match f (unsafe_get s i) with
	| Some c -> Buffer.add_char sc c
	| None   -> ()
    done;
    Buffer.contents sc

(* fold_left and fold_right by Eric C. Cooper *)
let fold_left f init str =
  let n = String.length str in
  let rec loop i result =
    if i = n then result
    else loop (i + 1) (f result str.[i])
  in
  loop 0 init

let fold_right f str init =
  let n = String.length str in
  let rec loop i result =
    if i = 0 then result
    else
      let i' = i - 1 in
      loop i' (f str.[i'] result)
  in
  loop n init

(* explode and implode from the OCaml Expert FAQ. *)
let explode s =
  let rec exp i l =
    if i < 0 then l else exp (i - 1) (s.[i] :: l) in
  exp (String.length s - 1) []

let to_list = explode

let implode l =
  let res = String.create (List.length l) in
  let rec imp i = function
  | [] -> res
  | c :: l -> res.[i] <- c; imp (i + 1) l in
  imp 0 l

let of_list = implode

let replace_chars f s =
	let len = String.length s in
	let tlen = ref 0 in
	let rec loop i acc =
		if i = len then
			acc
		else 
			let s = f (unsafe_get s i) in
			tlen := !tlen + length s;
			loop (i+1) (s :: acc)
	in
	let strs = loop 0 [] in
	let sbuf = create !tlen in
	let pos = ref !tlen in
	let rec loop2 = function
		| [] -> ()
		| s :: acc ->
			let len = length s in
			pos := !pos - len;
			blit s 0 sbuf !pos len;
			loop2 acc
	in
	loop2 strs;
	sbuf

let replace ~str ~sub ~by =
	try
		let i = find str sub in
		(true, (slice ~last:i str) ^ by ^ 
                   (slice ~first:(i+(String.length sub)) str))
        with
		Invalid_string -> (false, String.copy str)


let trim s =
  let len = length s          in
  let rec aux_1 i = (*locate leading whitespaces*)
    if   i = len then None (*The whole string is whitespace*)
    else if ExtChar.Char.is_whitespace (unsafe_get s i) then aux_1 (i + 1)
    else Some i in
  match aux_1 0 with
    | None -> ""
    | Some last_leading_whitespace ->
  let rec aux_2 i =
    if   i < 0 then None(*?*)
    else if ExtChar.Char.is_whitespace (unsafe_get s i) then aux_2 (i - 1)
    else Some i in
  match aux_2 (len - 1) with
    | None -> ""
    | Some first_trailing_whitespace ->
	sub s last_leading_whitespace (first_trailing_whitespace - last_leading_whitespace + 1)

let splice s1 off len s2 = 
  let len1 = length s1 and len2 = length s2 in
  let out_len = len1 - len + len2 in
  let s = create out_len in
  blit s1 0 s 0 off; (* s1 before splice point *)
  blit s2 0 s off len2; (* s2 at splice point *)
  blit s1 (off+len) s (off+len2) (len1 - (off+len)); (* s1 after off+len *)
  s

let is_empty s = length s = 0 

let compare_without_case s1 s2 = compare (String.lowercase s1) (String.lowercase s2)

module Cap =
struct
type 'a t = string
  constraint 'a = [< `Read | `Write] with sexp

let make          = make
let is_empty      = is_empty
let init          = init
let enum          = enum
let of_enum       = of_enum
let of_int        = of_int
let of_float      = of_float
let of_char       = of_char
let to_int        = to_int
let to_float      = to_float
let map           = map
let fold_left     = fold_left
let fold_right    = fold_right
let iter          = iter
let index         = index
let rindex        = rindex
let index_from    = index_from
let rindex_from   = rindex_from
let contains      = contains
let contains_from = contains_from
let rcontains_from= rcontains_from
let find          = find
let ends_with     = ends_with
let starts_with   = starts_with
let exists        = exists
let lchop         = lchop
let rchop         = rchop
let strip         = strip
let uppercase     = uppercase
let lowercase     = lowercase
let capitalize    = capitalize
let uncapitalize  = uncapitalize
let copy          = copy
let sub           = sub
let fill          = fill
let blit          = blit
let concat        = concat
let escaped       = escaped
let replace_chars = replace_chars
let replace       = replace
let split         = split
let nsplit        = nsplit
let join          = join
let slice         = slice
let explode       = explode
let implode       = implode
let compare       = compare
let compare_without_case = compare_without_case
let splice        = splice
let trim          = trim
let filter_map    = filter_map
let of_list       = of_list
let to_list       = to_list

external of_string : string -> _ t                = "%identity"
external to_string : [`Read | `Write] t -> string = "%identity"
external read_only : [> `Read] t -> [`Read] t     = "%identity"
external write_only: [> `Write] t -> [`Write] t   = "%identity"

external length : _ t  -> int = "%string_length"
external get : [> `Read] t -> int -> char = "%string_safe_get"
external set : [> `Write] t -> int -> char -> unit = "%string_safe_set"
external create : int -> _ t = "caml_create_string"
external unsafe_get : [> `Read] t -> int -> char = "%string_unsafe_get"
external unsafe_set : [> `Write] -> int -> char -> unit = "%string_unsafe_set"
external unsafe_blit :
  [> `Read] t -> int -> [> `Write] -> int -> int -> unit = "caml_blit_string" "noalloc"
external unsafe_fill :
  [> `Write] -> int -> int -> char -> unit = "caml_fill_string" "noalloc"

end
end


