﻿; ===================================================================================
; AHK Version ...: AHK_L 1.1.14.03 x64 Unicode
; Win Version ...: Windows 7 Professional x64 SP1
; Description ...: Checksum: MD4
;                  Calc MD4-Hash from String / Hex / File / Address
;                  http://en.wikipedia.org/wiki/MD4
; Version .......: 2014.04.09-1828
; Author ........: Bentschi
; Modified ......: jNizM
; ===================================================================================

; GLOBAL SETTINGS ===================================================================

#Warn
#NoEnv
#SingleInstance Force
SetBatchLines, -1

; SCRIPT ============================================================================

str := "The quick brown fox jumps over the lazy dog"
MsgBox, % "String:`n" (str) "`n`nMD4:`n" MD4(str)

hex := "54686520717569636b2062726f776e20666f78206a756d7073206f76657220746865206c617a7920646f67"
MsgBox, % "Hex:`n" (hex) "`n`nMD4:`n" HexMD4(hex)

file := "C:\Windows\notepad.exe"
MsgBox, % "File:`n" (file) "`n`nMD4:`n" FileMD4(file)

ExitApp


; MD4 ===============================================================================
MD4(string, encoding = "UTF-8")
{
    return CalcStringHash(string, 0x8002, encoding)
}
HexMD4(hexstring)
{
	return CalcHexHash(hexstring, 0x8002)
}
FileMD4(filename)
{
    return CalcFileHash(filename, 0x8002, 64 * 1024)
}
AddrMD4(addr, length)
{
    return CalcAddrHash(addr, length, 0x8002)
}

; CalcAddrHash ======================================================================
CalcAddrHash(addr, length, algid, byref hash = 0, byref hashlength = 0)
{
    static h := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, "a", "b", "c", "d", "e", "f"]
    static b := h.minIndex()
    hProv := hHash := o := ""
    if (DllCall("advapi32\CryptAcquireContext", "Ptr*", hProv, "Ptr", 0, "Ptr", 0, "UInt", 24, "UInt", 0xf0000000))
    {
        if (DllCall("advapi32\CryptCreateHash", "Ptr", hProv, "UInt", algid, "UInt", 0, "UInt", 0, "Ptr*", hHash))
        {
            if (DllCall("advapi32\CryptHashData", "Ptr", hHash, "Ptr", addr, "UInt", length, "UInt", 0))
            {
                if (DllCall("advapi32\CryptGetHashParam", "Ptr", hHash, "UInt", 2, "Ptr", 0, "UInt*", hashlength, "UInt", 0))
                {
                    VarSetCapacity(hash, hashlength, 0)
                    if (DllCall("advapi32\CryptGetHashParam", "Ptr", hHash, "UInt", 2, "Ptr", &hash, "UInt*", hashlength, "UInt", 0))
                    {
                        loop % hashlength
                        {
                            v := NumGet(hash, A_Index - 1, "UChar")
                            o .= h[(v >> 4) + b] h[(v & 0xf) + b]
                        }
                    }
                }
            }
            DllCall("advapi32\CryptDestroyHash", "Ptr", hHash)
        }
        DllCall("advapi32\CryptReleaseContext", "Ptr", hProv, "UInt", 0)
    }
    return o
}

; CalcStringHash ====================================================================
CalcStringHash(string, algid, encoding = "UTF-8", byref hash = 0, byref hashlength = 0)
{
    chrlength := (encoding = "CP1200" || encoding = "UTF-16") ? 2 : 1
    length := (StrPut(string, encoding) - 1) * chrlength
    VarSetCapacity(data, length, 0)
    StrPut(string, &data, floor(length / chrlength), encoding)
    return CalcAddrHash(&data, length, algid, hash, hashlength)
}

; CalcHexHash =======================================================================
CalcHexHash(hexstring, algid)
{
    length := StrLen(hexstring) // 2
    VarSetCapacity(data, length, 0)
    loop % length
    {
        NumPut("0x" SubStr(hexstring, 2 * A_Index - 1, 2), data, A_Index - 1, "Char")
    }
    return CalcAddrHash(&data, length, algid)
}

; CalcFileHash ======================================================================
CalcFileHash(filename, algid, continue = 0, byref hash = 0, byref hashlength = 0)
{
	fpos := ""
    if (!(f := FileOpen(filename, "r")))
    {
        return
    }
    f.pos := 0
    if (!continue && f.length > 0x7fffffff)
    {
        return
    }
    if (!continue)
    {
        VarSetCapacity(data, f.length, 0)
        f.rawRead(&data, f.length)
        f.pos := oldpos
        return CalcAddrHash(&data, f.length, algid, hash, hashlength)
    }
    hashlength := 0
    while (f.pos < f.length)
    {
        readlength := (f.length - fpos > continue) ? continue : f.length - f.pos
        VarSetCapacity(data, hashlength + readlength, 0)
        DllCall("RtlMoveMemory", "Ptr", &data, "Ptr", &hash, "Ptr", hashlength)
        f.rawRead(&data + hashlength, readlength)
        h := CalcAddrHash(&data, hashlength + readlength, algid, hash, hashlength)
    }
    return h
}