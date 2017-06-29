<?php

function access_denied($msg) {
  echo "access denied: ".$msg;
  die;
}

// not sure why, but let's deny access outside of QTS
if(!$_GET['windowId']) { header('Location: /'); exit; }

// determine NAS SID
if (isset($_COOKIE['QTS_SSID'])) {
  $NAS_SID = $_COOKIE['QTS_SSID'];
} else if (isset($_COOKIE['NAS_SID'])) {
  $NAS_SID = $_COOKIE['NAS_SID'];
} else {
  access_denied("no sid");
}

// check user status
exec("/sbin/user_cmd --xml --sid ".escapeshellarg($NAS_SID)." -l 100", $output, $status);
if($status != 0) { access_denied("user_cmd exit code"); }

// let's dig into the info we got
$xml = simplexml_load_string('<QDocRoot>'.implode('', $output).'</QDocRoot>');
if($xml->authPassed != 1 || $xml->isAdmin != 1 ) { access_denied("not authed or not admin"); }

// variables
$filename = "./config.conf";
$ui_info_file = "/var/lib/crashplan/.ui_info";
$ui_id = "None - Starting CrashPlan once first is needed";
$app_log_file = "../log/app.log";
$cp_version = "Could not find it";

if(file_exists($app_log_file)) {
  exec("/bin/grep -i CPVERSION $app_log_file | awk '/CPVERSION/{print $3}'", $temp);
  $cp_version = $temp[0];
}

// fetch ui id
if(file_exists($ui_info_file)) {
  $handle = fopen($ui_info_file, 'r');
  $ui_id = fgets($handle);
  fclose($handle);
}

// find memory available on device
$memDefault = 512;
$memTotal = round(exec("awk '/^MemTotal:/{print $2}' /proc/meminfo") / 1024, 0, PHP_ROUND_HALF_DOWN);
if($memTotal <= 2048) {
  $memStep = 256;
} else {
  $memStep = 512;
}

// find network interfaces available on device
$net_ifaces = array();
exec("for iface in $(/usr/bin/find /sys/class/net/ -type l | /bin/grep -iv \"lo\"); do iface=$(/usr/bin/basename \$iface); if /sbin/ifconfig \$iface | /bin/grep -i inet >/dev/null 2>&1; then echo \"\$iface;\$(/sbin/ifconfig \$iface | awk '/addr:/{print \$2}' | cut -f2 -d:;)\"; fi; done", $call_output);

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
    <title>CrashPlan</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <link rel="icon" type="image/png" href="images/favicon.png" />
    <link rel="stylesheet" type="text/css" href="style.css">
  </head>
  <body>
    <div id="logo"></div>
    <div id="main">
      <form method="post">
        <div class="item section">
          <img src="images/identity.png" class="fleft" />
          <h1 class="clear">Identity</h1>
        </div>
        <div class="item">
          <div><strong>Version:</strong>&nbsp;<?php echo $cp_version; ?></div>
          <div style="margin-top: 5px;"><strong>ID:</strong>&nbsp;<?php echo $ui_id; ?></div>
        </div>
        
        <div class="item section">
          <img src="images/card.png" class="fleft" />
          <h1 class="clear">Network<?php if(!$ip_configured) { echo " (not yet configured)"; } ?></h1>
        </div>
        <div class="item">
          <strong>Interface:</strong>&nbsp;<select name="interface">
            <?php if(!$ip_configured) { ?><option value="" SELECTED>-</option><?php } ?>
            <?php foreach($net_ifaces as $iface => $ip) { ?>
            <option value="<?php echo $iface ?>"<?php if(isset($config['interface']) && $config['interface']=="$iface") { echo " SELECTED"; }?>><?php echo $ip; ?></option>
            <?php } ?>
          </select>
        </div>
        
        <div class="item section">
          <img src="images/ram.png" class="fleft" />
          <h1 class="clear">Memory</h1>
        </div>
        <div class="item">
          <strong>Allocation:</strong>&nbsp;<select name="memory">
            <?php for($m = $memStep; $m <= $memTotal; $m += $memStep) { ?>
            <option value="<?php echo ($m); ?>"<?php if(isset($config['memory']) && $config['memory'] == $m || !isset($config['memory']) && $memDefault == $m) { echo " selected"; } ?>><?php echo ($m) ?> Mb<?php if($m == $memDefault) { echo " (default)"; } ?></option>
            <?php } ?>
          </select>
        </div>
        
        <div class="item section separation">
          <input type="submit" value="Submit" name="posted" /><span id="warning"><u><b>/!\</b></u> Note that you will have to restart the CP service to take it into account!</div>
        </div>
      </form>
    </div>
  </body>
</html>
