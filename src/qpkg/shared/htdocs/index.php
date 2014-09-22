<?php
$filename = "./config.conf";
$memStep = 256;
$memDefault = 512;
$memTotal = ceil(round(exec("awk '/^MemTotal:/{print $2}' /proc/meminfo") / 1024, 0) / $memStep) * $memStep;
exec("for interface in \$(/sbin/ifconfig -a | grep -i hwaddr | awk '{ print \$1 }'); do echo -n \"\${interface};\"; /sbin/ifconfig \$interface | awk '/addr:/{print \$2}' | cut -f2 -d:; done", $if_addr);
// Save posted data
$config = array();
if(isset($_POST['posted'])) {
	$config = array("interface" => $_POST['interface'], "memory" => $_POST['memory']);

	// Save new config
	$handle = fopen($filename, "w+");
        fwrite($handle, "interface=" . $config['interface'] .  "\n");
        fwrite($handle, "memory=" . $config['memory']);
        fclose($handle);
} elseif(file_exists($filename)) {
	// Read config file content
	$fileContent = explode("\n", file_get_contents($filename));
	while(list(, $item) = each($fileContent)) {
		$cfgLine = explode("=", $item);
		$config[$cfgLine[0]] = $cfgLine[1];
	}
}
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
<title>CrashPlan Administration</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<link rel="icon" type="image/png" href="images/favicon.png" />
<link rel="stylesheet" type="text/css" href="style.css">
</head>
<body>
	<div id="main">
		<div id="top">
			<a href="cgi-bin/backup.cgi"><img src="images/download.gif" />Download configuration and log files</a>
			<div class="topSpace">
				<a href="http://forum.qnap.com/viewforum.php?f=227"><img src="images/forum.gif" />Got a question ? Need help ? Want to thank packager ?</a>
			</div>
		</div>

		<form method="post">
			<div id="bottomLeft">
				<img src="images/<?php if(!isset($config['interface'])) { echo "warning.gif"; } else { echo "success.gif";  } ?>"<?php if(!isset($config['interface'])) { echo " title=\"Listening IP not yet set!\""; } ?> />
				IP CrashPlan will be listening on:
				<select name="interface">
					<?php foreach($if_addr as $tmp) {
						$tmp=explode(';', $tmp);
						if($tmp[1]) {
					?>
							<option value="<?php echo $tmp[0] ?>"<?php if(isset($config['interface']) && $config['interface']=="$tmp[0]") { echo " SELECTED"; }?>><?php echo $tmp[1]; ?></option>
                                	<?php 	}
					}
					?>
				</select>

				<div class="topSpace">
					<img src="images/ram.gif" />
					CrashPlan's Java memory allocation
					<select name="memory">
						<?php
						for($m = $memStep; $m <= $memTotal; $m += $memStep) {
						?>
							<option value="<?php echo ($m); ?>"<?php if(isset($config['memory']) && $config['memory'] == $m) { echo " selected"; } ?>><?php echo ($m) ?> Mb<?php if($m == $memDefault) { echo " (default)"; } ?></option>
						<?php
						}
						?>
					</select>
				</div>
			</div>

			<div id="bottomRight">
				<input type="submit" value="Save" name="posted" />
				<div class="topSpace">Note that you will have to restart the CP service to take it into account!</div>
			</div>
		</form>
	</div>
</body>
</html>
