#include <File.au3>
#include <FileConstants.au3>
#include <Array.au3>
#include <Crypt.au3>
#include <Date.au3>
#include <GUIConstantsEx.au3>
#include <MsgBoxConstants.au3>
#include <WinAPIReg.au3>

Global $hGUI

Global Const $sRegPath = "HKEY_CLASSES_ROOT\Directory\Background\shell\RemoveDuplicateFiles"

HotKeySet ("{F1}" , "_OpenContextMenuManager")

; Kiểm tra nếu script được chạy với tham số dòng lệnh
If $CmdLine[0] > 0 Then
    Local $sDirPath = $CmdLine[1]
    RunMainFunction($sDirPath)
Else
    _ShowContextMenuGUI()
EndIf

Func AddContextMenu()
    Local $sExePath = FileGetShortName(@ScriptFullPath)
    Local $sCommand = '"' & $sExePath & '" "%V"'

    ; Tạo registry entry
    RegWrite($sRegPath, "", "REG_SZ", "Remove Duplicate Files")
    RegWrite($sRegPath & "\command", "", "REG_SZ", $sCommand)

    MsgBox($MB_OK, "Success", "Context menu entry added successfully.")
EndFunc

Func RemoveContextMenu()
    ; Xóa registry entry
    RegDelete($sRegPath)

    MsgBox($MB_OK, "Success", "Context menu entry removed successfully.")
EndFunc

Func RunMainFunction($sDirPath)
    _ShowDuplicateFileRemoverGUI($sDirPath)
EndFunc

Func _ProcessFiles($sDirPath, $sFlag)
    ; Tạo hoặc xóa file log trong thư mục
    Local $hFile = FileOpen($sDirPath & "\_log.txt", $FO_OVERWRITE)

    ; Nếu không thể tạo hoặc xóa file log, thoát script
    If $hFile = -1 Then
        MsgBox(16, "Error", "Could not create or clear log file")
        Exit
    EndIf

    ; Ghi thời gian bắt đầu
    FileWriteLine($hFile, "Check duplicate files by nducmd")
    FileWriteLine($hFile, "Start at: " & _NowCalc())
    FileWriteLine($hFile, "--------------------------------")
    ; Đóng file log
    FileClose($hFile)

    ; Lấy tất cả file trong thư mục
    Local $aFiles = _FileListToArray($sDirPath, "*", $FLTA_FILES)
    ; Tạo mảng lưu hash của các file
    Local $aHashes[1]
    ; Khởi tạo bộ đếm file đã xử lí
    Local $iDeletedFiles = 0

    If $sFlag = "M" Then
        ; Tạo thư mục sao lưu nếu không tồn tại
        If Not FileExists($sDirPath & "\_duplicate") Then
            DirCreate($sDirPath & "\_duplicate")
        EndIf
        For $i = 1 To UBound($aFiles) - 1
            Local $sHash = _Crypt_HashFile($sDirPath & "\" & $aFiles[$i], $CALG_SHA_256)  ; Tạo hash file
            ; Kiểm tra nếu hash đã tồn tại
            If _ArraySearch($aHashes, $sHash) >= 0 Then
                FileMove($sDirPath & "\" & $aFiles[$i], $sDirPath & "\_duplicate\" & $aFiles[$i], $FC_CREATEPATH) ; Di chuyển file trùng lặp
                $iDeletedFiles += 1 ; Tăng bộ đếm file đã di chuyển
                $hFile = FileOpen($sDirPath & "\_log.txt", $FO_APPEND) ; Ghi tên file đã di chuyển vào file log
                FileWriteLine($hFile, _NowCalc() & " Moved file: " & $aFiles[$i])
                FileClose($hFile)
            Else
                _ArrayAdd($aHashes, $sHash)  ; Thêm hash vào mảng nếu nó không tồn tại
            EndIf
        Next
    Else
        For $i = 1 To UBound($aFiles) - 1
            Local $sHash = _Crypt_HashFile($sDirPath & "\" & $aFiles[$i], $CALG_SHA_256) ; Tạo hash file
            ; Kiểm tra nếu hash đã tồn tại
            If _ArraySearch($aHashes, $sHash) >= 0 Then
                FileDelete($sDirPath & "\" & $aFiles[$i])  ; Xóa file trùng lặp
                $iDeletedFiles += 1 ; Tăng bộ đếm file đã xóa
                $hFile = FileOpen($sDirPath & "\_log.txt", $FO_APPEND)  ; Ghi tên file đã xóa vào file log
                FileWriteLine($hFile, _NowCalc() & " Deleted file: " & $aFiles[$i])
                FileClose($hFile)
            Else
                _ArrayAdd($aHashes, $sHash) ; Thêm hash vào mảng nếu nó không tồn tại
            EndIf
        Next
    EndIf

    _ArrayDelete($aHashes, 0)
	
    ; Ghi thời gian kết thúc
    Local $hFile = FileOpen($sDirPath & "\_log.txt", $FO_APPEND)
    FileWriteLine($hFile, "--------------------------------")
    FileWriteLine($hFile, "End at: " & _NowCalc())
    FileClose($hFile)

    ; Thông báo số lượng file đã xóa hoặc di chuyển
    If $sFlag = "D" Then
        MsgBox(0, "Files Deleted", "Number of deleted files: " & $iDeletedFiles)
    ElseIf $sFlag = "M" Then
        MsgBox(0, "Files Moved", "Number of moved files: " & $iDeletedFiles)
    EndIf
EndFunc


; Hàm mở GUI sửa context menu
Func _OpenContextMenuManager()
	
	; Đóng GUI hiện tại nếu có
    If IsHWnd($hGUI) Then
        GUIDelete($hGUI)
    EndIf
	
    ; Tạo GUI sửa context menu
   _ShowContextMenuGUI()
EndFunc

Func _ShowContextMenuGUI()
    $hGUI = GUICreate("Duplicate File Remover", 300, 150)
    Local $addButton = GUICtrlCreateButton("Add to Context Menu", 50, 30, 200, 30)
    Local $removeButton = GUICtrlCreateButton("Remove from Context Menu", 50, 80, 200, 30)
    GUISetState(@SW_SHOW, $hGUI)

    While 1
        Local $msg = GUIGetMsg()
        Switch $msg
            Case $GUI_EVENT_CLOSE
                GUIDelete($hGUI)
                ExitLoop
            Case $addButton
                GUIDelete($hGUI)
                AddContextMenu()
                ExitLoop
            Case $removeButton
                GUIDelete($hGUI)
                RemoveContextMenu()
                ExitLoop
        EndSwitch
    WEnd
	GUIDelete($hGUI)
	Exit
EndFunc

Func _ShowDuplicateFileRemoverGUI($sDirPath)
    $hGUI = GUICreate("Duplicate File Remover", 300, 150)
    Local $deleteButton = GUICtrlCreateButton("Delete Duplicate Files", 50, 80, 200, 30)
    Local $moveButton = GUICtrlCreateButton("Move Duplicate Files", 50, 30, 200, 30)
	GUICtrlCreateLabel("F1 = Option", 10, 130, 80, 20)
    GUISetState(@SW_SHOW, $hGUI)

    While 1
        Local $msg = GUIGetMsg()
        Switch $msg
            Case $GUI_EVENT_CLOSE
                GUIDelete($hGUI)
                ExitLoop
            Case $deleteButton
                GUIDelete($hGUI)
                _ProcessFiles($sDirPath, "D")
                ExitLoop
            Case $moveButton
                GUIDelete($hGUI)
                _ProcessFiles($sDirPath, "M")
                ExitLoop
        EndSwitch
    WEnd
	GUIDelete($hGUI)
	Exit
EndFunc
