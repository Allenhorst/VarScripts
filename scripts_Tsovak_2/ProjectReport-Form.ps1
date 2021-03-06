
#region Import the Assemblies
[reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null
[reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
#endregion

#region Generated Form Objects
$form1 = New-Object System.Windows.Forms.Form
$richTextBox1 = New-Object System.Windows.Forms.RichTextBox
$statusBar2 = New-Object System.Windows.Forms.StatusBar
$panel2 = New-Object System.Windows.Forms.Panel
$button6 = New-Object System.Windows.Forms.Button
$textBox1 = New-Object System.Windows.Forms.TextBox
$label2 = New-Object System.Windows.Forms.Label
$button5 = New-Object System.Windows.Forms.Button
$button4 = New-Object System.Windows.Forms.Button
$button3 = New-Object System.Windows.Forms.Button
$comboBox2 = New-Object System.Windows.Forms.ComboBox
$checkBox1 = New-Object System.Windows.Forms.CheckBox
$button2 = New-Object System.Windows.Forms.Button
$dateTimePicker1 = New-Object System.Windows.Forms.DateTimePicker
$label1 = New-Object System.Windows.Forms.Label
$button1 = New-Object System.Windows.Forms.Button
$comboBox1 = New-Object System.Windows.Forms.ComboBox
$InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState
#endregion Generated Form Objects


#region Generated Form Code
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 499
$System_Drawing_Size.Width = 893
$form1.ClientSize = $System_Drawing_Size
$form1.DataBindings.DefaultDataSourceUpdateMode = 0
$form1.Name = "form1"
$form1.Text = "TeamCity Report"

$richTextBox1.DataBindings.DefaultDataSourceUpdateMode = 0
$richTextBox1.Dock = 5
$richTextBox1.Font = New-Object System.Drawing.Font("Courier New",9.75,0,3,1)
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 0
$System_Drawing_Point.Y = 108
$richTextBox1.Location = $System_Drawing_Point
$richTextBox1.Name = "richTextBox1"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 369
$System_Drawing_Size.Width = 893
$richTextBox1.Size = $System_Drawing_Size
$richTextBox1.TabIndex = 6
$richTextBox1.Text = ""
$richTextBox1.WordWrap = $False

$form1.Controls.Add($richTextBox1)

$statusBar2.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 0
$System_Drawing_Point.Y = 477
$statusBar2.Location = $System_Drawing_Point
$statusBar2.Name = "statusBar2"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 22
$System_Drawing_Size.Width = 893
$statusBar2.Size = $System_Drawing_Size
$statusBar2.TabIndex = 4

$form1.Controls.Add($statusBar2)


$panel2.DataBindings.DefaultDataSourceUpdateMode = 0
$panel2.Dock = 1
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 0
$System_Drawing_Point.Y = 0
$panel2.Location = $System_Drawing_Point
$panel2.Name = "panel2"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 108
$System_Drawing_Size.Width = 893
$panel2.Size = $System_Drawing_Size
$panel2.TabIndex = 2

$form1.Controls.Add($panel2)

$button6.DataBindings.DefaultDataSourceUpdateMode = 0

$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 293
$System_Drawing_Point.Y = 75
$button6.Location = $System_Drawing_Point
$button6.Name = "button6"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 23
$System_Drawing_Size.Width = 75
$button6.Size = $System_Drawing_Size
$button6.TabIndex = 12
$button6.Text = "R47 Report"
$button6.UseVisualStyleBackColor = $True
$button6.add_Click($button6_OnClick)

$panel2.Controls.Add($button6)

$textBox1.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 53
$System_Drawing_Point.Y = 75
$textBox1.Location = $System_Drawing_Point
$textBox1.Name = "textBox1"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 20
$System_Drawing_Size.Width = 37
$textBox1.Size = $System_Drawing_Size
$textBox1.TabIndex = 11
$textBox1.Text = "2"

$panel2.Controls.Add($textBox1)

$label2.DataBindings.DefaultDataSourceUpdateMode = 0

$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 12
$System_Drawing_Point.Y = 78
$label2.Location = $System_Drawing_Point
$label2.Name = "label2"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 19
$System_Drawing_Size.Width = 49
$label2.Size = $System_Drawing_Size
$label2.TabIndex = 10
$label2.Text = "Days"

$panel2.Controls.Add($label2)


$button5.DataBindings.DefaultDataSourceUpdateMode = 0

$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 197
$System_Drawing_Point.Y = 75
$button5.Location = $System_Drawing_Point
$button5.Name = "button5"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 23
$System_Drawing_Size.Width = 75
$button5.Size = $System_Drawing_Size
$button5.TabIndex = 9
$button5.Text = "R37 Report"
$button5.UseVisualStyleBackColor = $True
$button5.add_Click($button5_OnClick)

$panel2.Controls.Add($button5)


$button4.DataBindings.DefaultDataSourceUpdateMode = 0

$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 96
$System_Drawing_Point.Y = 75
$button4.Location = $System_Drawing_Point
$button4.Name = "button4"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 23
$System_Drawing_Size.Width = 83
$button4.Size = $System_Drawing_Size
$button4.TabIndex = 8
$button4.Text = "Trunk Report"
$button4.UseVisualStyleBackColor = $True
$button4.add_Click($handler_button4_Click)

$panel2.Controls.Add($button4)


$button3.DataBindings.DefaultDataSourceUpdateMode = 0

$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 498
$System_Drawing_Point.Y = 10
$button3.Location = $System_Drawing_Point
$button3.Name = "button3"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 23
$System_Drawing_Size.Width = 88
$button3.Size = $System_Drawing_Size
$button3.TabIndex = 7
$button3.Text = "970 Test List"
$button3.UseVisualStyleBackColor = $True
$button3.add_Click($handler_button3_Click)

$panel2.Controls.Add($button3)

$comboBox2.DataBindings.DefaultDataSourceUpdateMode = 0
$comboBox2.FormattingEnabled = $True
$comboBox2.Items.Add("-12")|Out-Null
$comboBox2.Items.Add("-11")|Out-Null
$comboBox2.Items.Add("-10")|Out-Null
$comboBox2.Items.Add("-09")|Out-Null
$comboBox2.Items.Add("-08")|Out-Null
$comboBox2.Items.Add("-07")|Out-Null
$comboBox2.Items.Add("-06")|Out-Null
$comboBox2.Items.Add("-05")|Out-Null
$comboBox2.Items.Add("-04")|Out-Null
$comboBox2.Items.Add("-03")|Out-Null
$comboBox2.Items.Add("-02")|Out-Null
$comboBox2.Items.Add("-01")|Out-Null
$comboBox2.Items.Add("-00")|Out-Null
$comboBox2.Items.Add("+01")|Out-Null
$comboBox2.Items.Add("+02")|Out-Null
$comboBox2.Items.Add("+03")|Out-Null
$comboBox2.Items.Add("+04")|Out-Null
$comboBox2.Items.Add("+05")|Out-Null
$comboBox2.Items.Add("+06")|Out-Null
$comboBox2.Items.Add("+07")|Out-Null
$comboBox2.Items.Add("+08")|Out-Null
$comboBox2.Items.Add("+09")|Out-Null
$comboBox2.Items.Add("+10")|Out-Null
$comboBox2.Items.Add("+11")|Out-Null
$comboBox2.Items.Add("+12")|Out-Null
$comboBox2.Items.Add("+13")|Out-Null
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 185
$System_Drawing_Point.Y = 45
$comboBox2.Location = $System_Drawing_Point
$comboBox2.Name = "comboBox2"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 21
$System_Drawing_Size.Width = 78
$comboBox2.Size = $System_Drawing_Size
$comboBox2.TabIndex = 6

$panel2.Controls.Add($comboBox2)


$checkBox1.DataBindings.DefaultDataSourceUpdateMode = 0

$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 416
$System_Drawing_Point.Y = 12
$checkBox1.Location = $System_Drawing_Point
$checkBox1.Name = "checkBox1"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 24
$System_Drawing_Size.Width = 104
$checkBox1.Size = $System_Drawing_Size
$checkBox1.TabIndex = 5
$checkBox1.Text = "Show Grid"
$checkBox1.UseVisualStyleBackColor = $True

$panel2.Controls.Add($checkBox1)


$button2.DataBindings.DefaultDataSourceUpdateMode = 0

$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 293
$System_Drawing_Point.Y = 42
$button2.Location = $System_Drawing_Point
$button2.Name = "button2"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 24
$System_Drawing_Size.Width = 75
$button2.Size = $System_Drawing_Size
$button2.TabIndex = 4
$button2.Text = "Get Report"
$button2.UseVisualStyleBackColor = $True
$button2.add_Click($button2_OnClick)

$panel2.Controls.Add($button2)

$dateTimePicker1.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 15
$System_Drawing_Point.Y = 46
$dateTimePicker1.Location = $System_Drawing_Point
$dateTimePicker1.Name = "dateTimePicker1"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 20
$System_Drawing_Size.Width = 158
$dateTimePicker1.Size = $System_Drawing_Size
$dateTimePicker1.TabIndex = 3

$panel2.Controls.Add($dateTimePicker1)

$label1.DataBindings.DefaultDataSourceUpdateMode = 0
$label1.Font = New-Object System.Drawing.Font("Microsoft Sans Serif",10,0,3,1)

$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 12
$System_Drawing_Point.Y = 14
$label1.Location = $System_Drawing_Point
$label1.Name = "label1"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 21
$System_Drawing_Size.Width = 59
$label1.Size = $System_Drawing_Size
$label1.TabIndex = 2
$label1.Text = "Project"

$panel2.Controls.Add($label1)


$button1.DataBindings.DefaultDataSourceUpdateMode = 0
$button1.Font = New-Object System.Drawing.Font("Arial Narrow",9,0,3,1)

$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 374
$System_Drawing_Point.Y = 10
$button1.Location = $System_Drawing_Point
$button1.Name = "button1"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 26
$System_Drawing_Size.Width = 26
$button1.Size = $System_Drawing_Size
$button1.TabIndex = 1
$button1.Text = "↻"
$button1.UseVisualStyleBackColor = $True
$button1.add_Click($handler_button1_Click)

$panel2.Controls.Add($button1)

$comboBox1.DataBindings.DefaultDataSourceUpdateMode = 0
$comboBox1.FormattingEnabled = $True
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 76
$System_Drawing_Point.Y = 14
$comboBox1.Location = $System_Drawing_Point
$comboBox1.Name = "comboBox1"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 21
$System_Drawing_Size.Width = 292
$comboBox1.Size = $System_Drawing_Size
$comboBox1.TabIndex = 0

$panel2.Controls.Add($comboBox1)


#endregion Generated Form Code

$form1.WindowState = $InitialFormWindowState
