<?php
require $_SERVER['DOCUMENT_ROOT'] . '/common/php/php_start.php';
require 'includes/php_auth_check.php';
?>

<!DOCTYPE html>
<html>
	<head>

		<title><?php echo $phrases['home-page-title'];?></title>
		<?php include $_SERVER['DOCUMENT_ROOT'] . '/common/php/head.php';?>

		</head>
		<body class="cust-dark1">

			<?php require '../common/navbar/navbar.php';?>

			<div class="container">
				<div class="row">
					<?php
					$default_id=get_default_category_id($con, $_SESSION['user-details']['id']);
					$categories=get_categories($con, $_SESSION['user-details']['id']);
					foreach($categories as $category) {
						$onclick='onclick="showMenu(\'' . $category['id'] . '\')"';
						$cursor='pointer';
						if($category['id'] == $default_id) {
							$category['name'] = $phrases['default-category-name'];
							$onclick='';
							$cursor='default';
						}
					echo '
					<div class="col-lg-4 col-md-4 col-sm-12">
					   <div ' . 
							$onclick . ' 
							style="
								display: flex; 
								justify-content: center; 
								align-items: center; 
								text-decoration: none; 
								color: ' . $category['text_color'] . '; 
								background-color: ' . $category['background_color'] . ';
								height: 150px; 
								border: 1px solid ' . $category['text_color'] . '; 
								border-radius: 5px; 
								margin-bottom: 15px;
								cursor: ' . $cursor . ';
								" 
							class="rounded"
						>' . 
							$category['name'] . '
						</div>
					</div>';
					}
					?>

					<div class="col-lg-4 col-md-4 col-sm-12">
						<a 
							href="category_edit.php" 
							style="display: flex; 
								justify-content: center; 
								align-items: center; 
								text-decoration: none; 
								color: white; height: 150px; 
								border: 1px solid #ddd; 
								box-shadow: 2px 2px 5px rgba(0,0,0,0.3); 
								border-radius: 5px; 
								margin-bottom: 15px;
								cursor: pointer;" 
							class="bg-info rounded"
						>
							<?php include '/home/gchalakov/zadachnik/html/common/php/plus.php';?>
						</a>
					</div>
				</div>

				<div id="overlay" class="overlay"></div>

				<div id="menu" class="hidden-menu">
				<p><?php echo $phrases['categories-hidden-menu-question'];?></p>
					<a id="edit" href=""><?php echo $phrases['categories-hidden-menu-edit'];?></a>
					<a id="delete" href=""><?php echo $phrases['categories-hidden-menu-delete'];?></a>
				</div>

			   <script>
				function showMenu(id) {
					var overlay = document.getElementById('overlay');
					var menu = document.getElementById('menu');
					document.getElementById('edit').href = "category_edit.php?id=" + id;
					document.getElementById('delete').href = "category_delete.inc.php?id=" + id;
					overlay.style.display = "block";
					menu.style.display = "block";
				}

				// Close the dropdown menu if the user clicks outside of it
				window.onclick = function(event) {
					if (!event.target.matches('.rounded')) {
						var overlay = document.getElementById('overlay');
						var menu = document.getElementById("menu");
						if (menu.style.display === "block") {
							overlay.style.display = "none";
							menu.style.display = "none";
						}
					}
				}
				</script>

				<script src="/common/scripts/form_mandatory_fields.js"></script>
				<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js" integrity="sha384-C6RzsynM9kWDrMNeT87bh95OGNyZPhcTNXj1NW7RuBCsyN/o0jlpcV8Qyq46cDfL" crossorigin="anonymous"></script>

		</body>
</html>

