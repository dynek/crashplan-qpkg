<?php
// variables
$filename = "./config.conf";
$memStep = 256;
$memDefault = 512;
$ui_info_file = "/var/lib/crashplan/.ui_info";
$ui_id = "None - Starting CrashPlan once first is needed";

// fetch ui id
if(file_exists($ui_info_file)) {
    $handle = fopen($ui_info_file, 'r');
    $ui_id = fgets($handle);
    fclose($handle);
}

// find memory available on device
$memTotal = ceil(round(exec("awk '/^MemTotal:/{print $2}' /proc/meminfo") / 1024, 0) / $memStep) * $memStep;

// find network interfaces available on device
$net_ifaces = array();
exec("for interface in \$(/sbin/ifconfig -a | grep -i hwaddr | awk '{ print \$1 }'); do echo -n \"\${interface};\"; /sbin/ifconfig \$interface | awk '/addr:/{print \$2}' | cut -f2 -d:; done", $call_output);
// create an array from that for next operations (even though most people will only have a single interface w/ an ip addr defined)
foreach($call_output as $tmp) {
    list($iface, $ip) = explode(';', $tmp);
    if($ip) { $net_ifaces[$iface] = $ip; }
    unset($tmp, $iface, $ip);
}
unset($call_output);

// Save posted data
$config = array();
if(isset($_POST['posted'])) {
    $config = array("interface" => $_POST['interface'], "memory" => $_POST['memory']);

    // Save new config
    $handle = fopen($filename, "w+");
    if($config['interface']) { fwrite($handle, "interface=" . $config['interface'] .  "\n"); }
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

// was an iface/ip configured
$ip_configured = true;
if(!isset($config['interface']) || (isset($config['interface']) && !array_key_exists($config['interface'], $net_ifaces))) { $ip_configured = false; }
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
                    <img src="images/id.gif" />
                    ID: <?php echo $ui_id; ?>

                    <div class="topSpace">
                        <img src="images/<?php if(!$ip_configured) { echo "warning.gif"; } else { echo "success.gif";  } ?>"<?php if(!$ip_configured) { echo " title=\"Listening IP not yet set!\""; } ?> />
                        IP CrashPlan will be listening on:
                        <select name="interface">
                            <?php if(!$ip_configured) { ?><option value="" SELECTED>-</option><?php } ?>
                            <?php foreach($net_ifaces as $iface => $ip) { ?>
                            <option value="<?php echo $iface ?>"<?php if(isset($config['interface']) && $config['interface']=="$iface") { echo " SELECTED"; }?>><?php echo $ip; ?></option>
                            <?php } ?>
                        </select>
                    </div>

                    <div class="topSpace">
                        <img src="images/ram.gif" />
                        CrashPlan's Java memory allocation
                        <select name="memory">
                            <?php for($m = $memStep; $m <= $memTotal; $m += $memStep) { ?>
                            <option value="<?php echo ($m); ?>"<?php if(isset($config['memory']) && $config['memory'] == $m) { echo " selected"; } ?>><?php echo ($m) ?> Mb<?php if($m == $memDefault) { echo " (default)"; } ?></option>
                            <?php } ?>
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
