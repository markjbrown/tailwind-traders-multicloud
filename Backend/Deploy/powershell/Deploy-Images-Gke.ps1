#! /usr/bin/pwsh

Param(
    [parameter(Mandatory=$false)][string]$name = "tailwindtraders",
    [parameter(Mandatory=$true)][string]$gkeName,
    [parameter(Mandatory=$true)][string]$gkeRegion,
    [parameter(Mandatory=$true)][string]$projectId,
    [parameter(Mandatory=$false)][string]$tag="latest",
    [parameter(Mandatory=$false)][string]$charts = "*",
    [parameter(Mandatory=$false)][string]$valuesFile = "",
    [parameter(Mandatory=$false)][string]$namespace = "",
    [parameter(Mandatory=$false)][string][ValidateSet('prod','staging','none','custom', IgnoreCase=$false)]$tlsEnv = "none",
    [parameter(Mandatory=$false)][string]$tlsHost="gke.tailwind-traders.net",
    [parameter(Mandatory=$false)][string]$tlsSecretName="tt-tls-custom",
    [parameter(Mandatory=$false)][bool]$autoscale=$false
)

function validate {
    $valid = $true

    if ([string]::IsNullOrEmpty($gkeName)) {
        Write-Host "No GKE name. Use -gkeName to specify name" -ForegroundColor Red
        $valid=$false
    }

    # if ([string]::IsNullOrEmpty($gkeHost) -and $tlsEnv -ne "custom")  {
    #     Write-Host "GKE host of HttpRouting can't be found. Are you using right GKE ($gkeName)?" -ForegroundColor Red
    #     $valid=$false
    # }     
    # if ([string]::IsNullOrEmpty($gcrRegistry))  {
    #     Write-Host "ECR login server can't be found. Are you using the right AWS account?" -ForegroundColor Red
    #     $valid=$false
    # }

    if ($tlsEnv -eq "custom" -and [string]::IsNullOrEmpty($tlsSecretName)) {
        Write-Host "If tlsEnv is custom must use -tlsSecretName to set the TLS secret name (you need to install this secret manually)"
        $valid=$false
    }

    if ($tlsEnv -eq "custom" -and [string]::IsNullOrEmpty($tlsHost)) {
        Write-Host "If tlsEnv is custom must use -tlsHost to set the hostname of GKE (inferred name of Http Application Routing won't be used)"
        $valid=$false
    }

    if ($valid -eq $false) {
        exit 1
    }
}

function createHelmCommand([string]$command) {
    $tlsSecretNameToUse = ""
    if ($tlsEnv -eq "staging") {
        $tlsSecretNameToUse = "tt-letsencrypt-staging"
    }
    if ($tlsEnv -eq "prod") {
        $tlsSecretNameToUse = "tt-letsencrypt-prod"
    }
    if ($tlsEnv -eq "custom") {
        $tlsSecretNameToUse=$tlsSecretName
    }	    

    $newcommand = $command

    if (-not [string]::IsNullOrEmpty($namespace)) {
        $newcommand = "$newcommand --namespace $namespace" 
    }

    if (-not [string]::IsNullOrEmpty($tlsSecretNameToUse)) {
        $newcommand = "$newcommand --set ingress.tls[0].secretName=$tlsSecretNameToUse --set ingress.tls[0].hosts='{$gkeHost}'"
    }

    return "$newcommand";
}

Write-Host "--------------------------------------------------------" -ForegroundColor Yellow
Write-Host " Deploying images on cluster $gkeName"  -ForegroundColor Yellow
Write-Host " "  -ForegroundColor Yellow
Write-Host " Additional parameters are:"  -ForegroundColor Yellow
Write-Host " Release Name: $name"  -ForegroundColor Yellow
Write-Host " GKE to use: $gkeName and ECR"  -ForegroundColor Yellow
Write-Host " Images tag: $tag"  -ForegroundColor Yellow
Write-Host " TLS/SSL environment to enable: $tlsEnv"  -ForegroundColor Yellow
Write-Host " Namespace (empty means the one in .kube/config): $namespace"  -ForegroundColor Yellow
Write-Host " --------------------------------------------------------" 

$gcrLogin="us.gcr.io"
$gcrRegistry="$gcrLogin/$projectId"
$gcrUser="oauth2accesstoken"
$gcrPassword=$(gcloud auth print-access-token)

if ($tlsEnv -ne "custom" -and [String]::IsNullOrEmpty($tlsHost)) {
    $gkeHost=$(az aks show -n $gkeName -g $resourceGroup --query addonProfiles.httpapplicationrouting.config.HTTPApplicationRoutingZoneName -o json | ConvertFrom-Json)

    if (-not $gkeHost) {
        $gkeHost=$(az aks show -n $gkeName -g $resourceGroup --query addonProfiles.httpApplicationRouting.config.HTTPApplicationRoutingZoneName -o json | ConvertFrom-Json)
    }

    Write-Host "ecr login server is $gcrRegistry" -ForegroundColor Yellow
    Write-Host "gkeHost is $gkeHost" -ForegroundColor Yellow
}
else {
    $gkeHost=$tlsHost
}

validate

Push-Location $($MyInvocation.InvocationName | Split-Path)
Push-Location $(Join-Path .. helm)

Write-Host "Deploying charts $charts" -ForegroundColor Yellow
gcloud container clusters get-credentials $gkeName --region=$gkeRegion

if ([String]::IsNullOrEmpty($valuesFile)) {
    $valuesFile="gcp-gvalues.yaml"
}

Write-Host "Configuration file used is $valuesFile" -ForegroundColor Yellow

if ($charts.Contains("pr") -or  $charts.Contains("*")) {
    $useVnodes = $charts.Contains("pr!")
    Write-Host "Products chart - pr" -ForegroundColor Yellow
    $command = "helm upgrade --install $name-product products-api -f $valuesFile --set ingress.hosts='{$gkeHost}' --set image.repository=$gcrRegistry/product.api --set image.tag=$tag --set hpa.activated=$autoscale"
    if ($useVnodes) {
        Write-Host "Products chart - pr will run on virtual nodes" -ForegroundColor Yellow
        $command = "$command -f vnodes-values.yaml"
    }
    $command = createHelmCommand $command 
    Invoke-Expression "$command"
}

if ($charts.Contains("pf") -or  $charts.Contains("*")) {
    Write-Host "Profile chart - pf " -ForegroundColor Yellow
    $command = "helm upgrade --install $name-profile profiles-api -f $valuesFile --set ingress.hosts='{$gkeHost}' --set image.repository=$gcrRegistry/profile.api --set image.tag=$tag --set hpa.activated=$autoscale"
    $command = createHelmCommand $command 
    Invoke-Expression "$command"
}

if ($charts.Contains("pp") -or  $charts.Contains("*")) {
    Write-Host "Popular products chart - pp" -ForegroundColor Yellow
    $command = "helm upgrade --install $name-popular-product popular-products-api -f $valuesFile --set ingress.hosts='{$gkeHost}' --set image.repository=$gcrRegistry/popular-product.api --set image.tag=$tag --set initImage.repository=$gcrRegistry/popular-product-seed.api  --set initImage.tag=$tag --set hpa.activated=$autoscale"
    $command = createHelmCommand $command
    Invoke-Expression "$command"
}

if ($charts.Contains("st") -or  $charts.Contains("*")) {
    Write-Host "Stock -st" -ForegroundColor Yellow
    $command = createHelmCommand "helm upgrade --install $name-stock stock-api -f $valuesFile --set ingress.hosts='{$gkeHost}' --set image.repository=$gcrRegistry/stock.api --set image.tag=$tag --set hpa.activated=$autoscale"
    Invoke-Expression "$command"
}

if ($charts.Contains("ic") -or  $charts.Contains("*")) {
    Write-Host "Image Classifier -ic" -ForegroundColor Yellow
    $command = createHelmCommand "helm upgrade --install $name-image-classifier image-classifier-api -f $valuesFile --set ingress.hosts='{$gkeHost}' --set image.repository=$gcrRegistry/image-classifier.api --set image.tag=$tag --set hpa.activated=$autoscale"
    Invoke-Expression "$command"
}

if ($charts.Contains("ct") -or  $charts.Contains("*")) {
    Write-Host "Cart (Basket) -ct" -ForegroundColor Yellow
    $command = "helm  upgrade --install $name-cart cart-api -f $valuesFile --set ingress.hosts='{$gkeHost}' --set image.repository=$gcrRegistry/cart.api --set image.tag=$tag --set hpa.activated=$autoscale"
    $command = createHelmCommand $command
    Invoke-Expression "$command"
}

if ($charts.Contains("lg") -or  $charts.Contains("*")) {
    Write-Host "Login -lg" -ForegroundColor Yellow
    $command = "helm  upgrade --install $name-login login-api -f $valuesFile --set ingress.hosts='{$gkeHost}' --set image.repository=$gcrRegistry/login.api --set image.tag=$tag --set hpa.activated=$autoscale"
    $command = createHelmCommand $command
    Invoke-Expression "$command"
}

if ($charts.Contains("rr")) {
    Write-Host "Rewards Registration -rr" -ForegroundColor Yellow
    $command = createHelmCommand "helm upgrade --install $name-rewards-registration rewards-registration-api -f $valuesFile --set ingress.hosts='{$gkeHost}' --set image.repository=$gcrRegistry/rewards.registration.api --set image.tag=$tag --set hpa.activated=$autoscale"
    Invoke-Expression "$command"
}

if ($charts.Contains("mgw") -or  $charts.Contains("*")) {
    Write-Host "mobilebff -mgw" -ForegroundColor Yellow 
    $command = createHelmCommand "helm upgrade --install $name-mobilebff mobilebff -f $valuesFile --set ingress.hosts='{$gkeHost}' --set image.repository=$gcrRegistry/mobileapigw --set image.tag=$tag --set hpa.activated=$autoscale"
    Invoke-Expression "$command"
}

if ($charts.Contains("wgw") -or  $charts.Contains("*")) {
    Write-Host "webbff -wgw" -ForegroundColor Yellow
    $command = createHelmCommand "helm upgrade --install $name-webbff webbff -f $valuesFile --set ingress.hosts='{$gkeHost}' --set image.repository=$gcrRegistry/webapigw --set image.tag=$tag --set hpa.activated=$autoscale"
    Invoke-Expression "$command"
}

Pop-Location
Pop-Location

Write-Host "Tailwind traders deployed on GKE" -ForegroundColor Yellow