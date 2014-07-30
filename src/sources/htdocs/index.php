<?php
function getMemSlots($memStep) {
	$memTotal = 1;
	$meminfo = explode("\n", file_get_contents("/proc/meminfo"));
	while(list(, $memory) = each($meminfo)) {
		if (preg_match('/^MemTotal:\s+(\d+)\skB$/', $memory, $pieces)) {
			$memTotal = round($pieces[1] / 1024 / $memStep, 0);
			break;
		}
	}
return 1;
	return $memTotal;
}

$filename = "./config.conf";
$memStep = 256;
$memMinimum = 256;
$memDefault = 512;
$memSlots = getMemSlots($memStep);
$eth0_addr = exec("/sbin/ifconfig eth0 | awk '/addr:/{print $2}' | cut -f2 -d:");
$eth1_addr = exec("/sbin/ifconfig eth1 | awk '/addr:/{print $2}' | cut -f2 -d:");
$bond0_addr = exec("/sbin/ifconfig bond0 | awk '/addr:/{print $2}' | cut -f2 -d:");
$wlan0_addr = exec("/sbin/ifconfig wlan0 | awk '/addr:/{print $2}' | cut -f2 -d:");

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
<style>
	body {
		background-color: #598D1C;
		color: #FFFFFF;
		font-family: Arial;
		font-size: 8pt;
	}
	a {
		color: #FFFFFF;
		text-decoration: none;
	}
	div#main {
		width: 530px;
		height: 321px;
		background-image:url('images/main.jpg');
		margin-left: auto;
                margin-right: auto;
		margin-top: 100px;
		border: 1px solid #094713;
	}
	img {
                border: 0;
                vertical-align: middle;
                margin-right: 5px;
	}
	select {
		margin-left: 2px;
	}
	div#top {
                padding-top: 18px;
                padding-left: 160px;
        }
	div.topSpace {
		padding-top: 9px;
	}
	div#bottomLeft {
		margin-top: 200px;
		padding-left: 10px;
		width: 330px;
		float: left;
        }
	div#bottomRight {
		margin-top: 200px;
		margin-left: 10px;
		width: 180px;
		float: left;
	}
</style>
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
					<?php if($eth0_addr) { ?>
						<option value="eth0"<?php if(isset($config['interface']) && $config['interface']=="eth0") { echo " SELECTED"; }?>><?php echo $eth0_addr; ?></option>
					<?php } ?>
					<?php if($eth1_addr) { ?>
						<option value="eth1"<?php if(isset($config['interface']) && $config['interface']=="eth1") { echo " SELECTED"; }?>><?php echo $eth1_addr; ?></option>
					<?php } ?>
					<?php if($bond0_addr) { ?>
						<option value="bond0"<?php if(isset($config['interface']) && $config['interface']=="bond0") { echo " SELECTED"; }?>><?php echo $bond0_addr; ?></option>
                                	<?php } ?>
					<?php if($wlan0_addr) { ?>
						<option value="wlan0"<?php if(isset($config['interface']) && $config['interface']=="wlan0") { echo " SELECTED"; }?>><?php echo $wlan0_addr; ?></option>
                                	<?php } ?>
				</select>

				<div class="topSpace">
					<img src="images/ram.gif" />
					CrashPlan's Java memory allocation
					<select name="memory">
						<?php
						for($x = 1; $x <= $memSlots; $x++) {
							if($x * $memStep >= $memMinimum) {
						?>
								<option value="<?php echo ($x * $memStep); ?>"<?php if(isset($config['memory']) && $config['memory'] == ($x * $memStep)) { echo " SELECTED"; } ?>><?php echo ($x * $memStep) ?> Mb<?php if($x * $memStep == $memDefault) { echo " (default)"; } ?></option>
						<?php
							}
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
