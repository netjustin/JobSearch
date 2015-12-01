<#
usajobsSearch

last modified:	2015-11-30

purpose: 		simplify the search for government work

potential use case:
- fast, repeatable search
- support for matching against an array of values, or against a regular 
  expression, e.g. 'programm(er|ing)'

limitations:	
- does not return Assessment Questions

future work:
- store results to disk
- report additions since latest results on disk

api reference:	https://developer.usajobs.gov/Search-API/Overview

#>

#### GLOBALS ####

$apikey				= "INSERT YOUR API KEY"
$apiemail			= "INSERT YOUR ADDRESS"
$apihost			= "data.usajobs.gov"
$Headers 			= @{ 'User-Agent' = $apiemail; 'Authorization-Key' = $apikey; }
$UrlParent			= `
	"https://data.usajobs.gov/api/search?"
$CategoryRequire	= $True
$CategoryKey		= 'JobCategoryCode'
$CategoryValue		= '2210;1550'		# IT and CS
$GradeLowRequire	= $True
$GradeLowKey		= 'PayGradeLow'
$GradeLowValue		= '13'
$GradeHighRequire	= $True
$GradeHighKey		= 'PayGradeHigh'
$GradeHighValue		= '15'
$ClearanceRequire	= $True
$ClearanceKey		= 'SecurityClearanceRequired'
$ClearanceValue		= '1;2;3;4;5;6;7'	# clearance jobs
$PageSizeRequire	= $True
$PageSizeKey		= 'ResultsPerPage'
$PageSizeValue		= '250'
$WhoMayApplyRequire	= $True
$WhoMayApplyKey		= 'WhoMayApply'
$WhoMayApplyValue	= 'Public'
$OfferingRequire	= $True
$OfferingKey		= 'PositionOfferingTypeCode'
$OfferingValue		= '15317;15327'		# permanent (non-term) or multiple
$FieldRequire		= $True				# adds Duties
$FieldKey			= 'Fields'
$FieldValue			= 'full'
$ApplyFilter		= $True

# to lessen filtering, expand the $IncludeRegEx array, below, or set $ApplyFilter = $False
$IncludeRegEx		= 				`
	'python',						`
	'java',							`
	'C\+\+',						`
	'C Sharp'

	
$ExcludeRegEx		=	`
	'National Guard',	`
	'intern '

	
#### HELPER FUNC ####

function MatchRegex( $obj )
{
	(	[bool]( $obj.MatchedObjectDescriptor.QualificationSummary -match ( CatRegEx $IncludeRegEx ) ) 	  -or `
		[bool]( $obj.MatchedObjectDescriptor.UserArea.Details -match 	 ( CatRegEx $IncludeRegEx ) ) )		  `
																										 -and `
	(	[bool]( $obj.MatchedObjectDescriptor.QualificationSummary -notmatch ( CatRegEx $ExcludeRegEx ) ) -and `
		[bool]( $obj.MatchedObjectDescriptor.UserArea.Details -notmatch 	( CatRegEx $ExcludeRegEx ) )		)
}

function UrlCat()
{
	$UrlParent + 																	`
	('',( '&' + $CategoryKey	+ '=' + $CategoryValue    ))[$CategoryRequire]		+ `
	('',( '&' + $GradeHighKey	+ '=' + $GradeHighValue   ))[$GradeHighRequire]		+ `
	('',( '&' + $GradeLowKey	+ '=' + $GradeLowValue    ))[$GradeLowRequire]		+ `
	('',( '&' + $ClearanceKey	+ '=' + $ClearanceValue	  ))[$ClearanceRequire]		+ `
	('',( '&' + $PageSizeKey	+ '=' + $PageSizeValue	  ))[$PageSizeRequire]		+ `
	('',( '&' + $WhoMayApplyKey + '=' + $WhoMayApplyValue ))[$WhoMayApplyRequire]	+ `
	('',( '&' + $OfferingKey	+ '=' + $OfferingValue	  ))[$OfferingRequire]		+ `
	('',( '&' + $FieldKey		+ '=' + $FieldValue		  ))[$FieldRequire]
}

function CatRegEx( $arr )
{
	'(' + ( $arr -join ')|(') + ')' 
}

function ResultsFound()
{
	if ( $ApplyFilter -eq $True ) {
		$objResults | where { ( MatchRegex( $_ ) ) } 
	} else { $objResults }
}

function ResultsFiltered()
{
	if ( $ApplyFilter -eq $True ) {
		$objResults | where { !( MatchRegex( $_ ) ) }
	} else { $Null }
}

function DescendObj( $o )
{
	$o.SearchResult.SearchResultItems
}

function StripHtmlHeader ( $h )
{
	$intOffsetToJson	= $h.IndexOf('{')
	$strHttpResponse.Substring( $intOffsetToJson )
}

function QueryServer( $u )
{
	$Request 			= [Net.HttpWebRequest]::Create( $u )	# use Net.HttpWebRequest, for header modification
	$Request.Host 		= $apihost
	Invoke-WebRequest -Uri $u -Headers $Headers
}

function GetData()
{
	$url				= UrlCat
	$objHttpResponse	= QueryServer $url
	$strHttpResponse	= $objHttpResponse.RawContent
	$ResponseJSON 		= StripHtmlHeader  $strHttpResponse
	$objResponse 		= ConvertFrom-Json $ResponseJSON		# use PSCustomObject type
	DescendObj $objResponse
}

function GetStartCommands()
{
	foreach ( $url in $ResultsHit.MatchedObjectDescriptor.PositionUri ) { 'start {0}' -f $url }	
}

function GetHits()
{
	$ResultsHit.Count								
}

function GetMisses()
{
	$ResultsMiss.Count	
}

#### MAIN ####

$objResults 		= GetData


#### FILTERING ####

$ResultsHit		= ResultsFound
$ResultsMiss	= ResultsFiltered


#### BULK REPORTING -- GENERAL USES ARE IN THE BELOW 6 COMMANDS ####

# GetStartCommands	# paste return from this into cmd.exe
# GetHits			# e.g. 25
# GetMisses
# $ResultsHit.MatchedObjectDescriptor.PositionTitle 					| sort -Unique			# all job titles
# $ResultsHit.MatchedObjectDescriptor.OrganizationName 				| sort -Unique
# $ResultsHit.MatchedObjectDescriptor.UserArea.Details.SubAgencyName 	| sort -Unique


#### INDIVIDUAL JOB REPORTING ####
# $ResultsHit[0].MatchedObjectId			# e.g. 418411800
# $job				= $ResultsHit[0].MatchedObjectDescriptor
# ([int]$ResultsHit[0].MatchedObjectId)		# extend with additive property
# $job.UsaJobsId


# $job.psobject.Properties.Name
# $job.OrganizationName						# e.g. Consumer Financial Protection Bureau
# $job.PositionTitle						# e.g. CFPB Pathways Recent Graduate (Public Notice Flyer)
# $job.PublicationStartDate					# e.g. 2015-10-16T00:00:00Z
# $job.PositionEndDate						# e.g. 2016-10-15T00:00:00Z
# $job.UserArea.Details.WhoMayApply.Code	# e.g. 15514 (Open to All US Citizens)
# $job.QualificationSummary
# $job.UserArea.Details.psobject.Properties.Name
# $job.UserArea.Details.MajorDuties
# $job.UserArea.Details.SubAgencyName
