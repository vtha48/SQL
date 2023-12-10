Câu 1: Viết các trigger sau đây:
a. (1 điểm) Trigger trg_Posts_Insert có chức năng bắt lệnh INSERT trên bảng Posts sao
cho khi mỗi khi bổ sung một bài viết (Posts) thì tự động tăng số lượng bài viết của tài khoản (cột
NumOfPosts trong bảng Accounts)

--1a
if exists( select * from sys.objects where name='trg_Posts_Insert')
	drop trigger trg_Posts_Insert;
go

create trigger trg_Posts_Insert
on Posts
for insert
as
begin
	set nocount on;
	declare @AccountId int
	select @AccountId = AccountId from inserted

	update Accounts
	set NumOfPosts +=1
	where AccountId = @AccountId
end
go

--test case: 
insert into Posts(PostTitle,PostContent, AccountId)
values('ABC','A',2)

select * from Posts

--1b
Trigger trg_Comments_Insert có chức năng bắt lệnh INSERT trên bảng
Comments sao cho mỗi khi bổ sung một bài bình luận (Comment) thì tự động tăng số lượng bài bình
luận của tài khoản (cột NumOfComments trong bảng Accounts) và số lượng bài bình luận của bài
viết (cột NumOfComments của bảng Posts)
if exists( select * from sys.objects where name='trg_Comments_Insert')
	drop trigger trg_Comments_Insert;
go

create trigger trg_Comments_Insert
on Comments
for INSERT
as
begin
	set nocount on;
	declare @AccountId int
	select @AccountId = AccountId from inserted

	update Accounts
	set NumOfComments +=1
	where AccountId = @AccountId

	update Posts
	set NumOfComments +=1
	where AccountId = @AccountId

end
go

--test case: 
insert into Comments(PostId, AccountId, CommentText)
values(4,4,'D')

select * from Comments

--2a: Viết các thủ tục sau đây:
a. (1 điểm) proc_Posts_Insert
@PostTitle nvarchar(255),
@PostContent nvarchar(2000),
2
@AccountId int,
@PostId int output
Có chức năng tạo mới một bài viết. Tham số đầu ra @PostId trả về mã của bài viết được tạo mới
trong trường hợp thành công; Ngược lại, tham số này trả về giá trị nhỏ hơn hoặc bằng 0 nhằm cho
biết lý do không tạo được bài viết.

if exists( select * from sys.objects where name = 'proc_Posts_Insert')
	drop procedure proc_Posts_Insert;
go

create procedure proc_Posts_Insert
	@PostTitle nvarchar(255),
	@PostContent nvarchar(2000),
	@AccountId int,
	@PostId int output
as
begin
	set nocount on;
	if exists(select * from Posts where PostTitle is null)
		begin
			set @AccountId = 0;
			return;
		end

	if exists(select * from Posts where PostContent is null)
		begin
			set @AccountId = -1;
			return;
		end

	if not exists(select * from Accounts
			where  AccountId = @AccountId)
		begin
			set @AccountId = -2;
			return;
		end


	insert into Posts(PostTitle,PostContent,AccountId)
	values(@PostTitle,@PostContent,@AccountId)
	--where PostId = @PostId

	set @PostId = @@IDENTITY;
end
go

--test case:
declare @p int;
execute proc_Posts_Insert
	@PostTitle ='E',
	@PostContent ='ET',
	@AccountId=3,
	@PostId =@p output;
select @p;

--2b  proc_Accounts_Update
@AccountId int,
@AccountName nvarchar(100),
@Gender nvarchar(50),
@Email nvarchar(50),
@Result nvarchar(255) output
Có chức năng cập nhật thông tin của tài khoản có mã @AccountId. Nếu việc cập nhật là thành
công, tham số đầu ra @Result trả về chuỗi rỗng; Ngược lại, tham số này trả về chuỗi cho biết lý do
tại sao không cập nhật được dữ liệu

if exists( select * from sys.objects where name = 'proc_Accounts_Update')
	drop procedure proc_Accounts_Update;
go

create procedure proc_Accounts_Update
	@AccountId int,
	@AccountName nvarchar(100),
	@Gender nvarchar(50),
	@Email nvarchar(50),
	@Result nvarchar(255) output
as
begin
	set nocount on;

	if not exists(select * from Accounts
			where  AccountId = @AccountId)
		begin
			set @Result = N'Không tồn tại tài khoản này!';
			return;
		end
	if(@AccountName is null or @AccountName =N'')
		begin
			set @Result = N'AccountName sai!';
			return;
		end
	If exists( select * from Accounts
				where Email = @Email and AccountId<>@AccountId)
		begin
			set @Result = N'Email bị trùng!';
			return;
		end
	if(@Gender is null )
		begin
			set @Result = N'Gender sai!';
			return;
		end

	update Accounts
	set  AccountName = @AccountName, Gender = @Gender, Email=@Email
	where AccountId = @AccountId

	set @Result= N'';
end
go

--test case:
declare @r nvarchar(255);
execute proc_Accounts_Update
	@AccountId =7,
	@AccountName ='F',
	@Gender = 'Nam',
	@Email = 'F@gmail.com',
	@Result =@r output;
select @r;

--2c: proc_Posts_Select
@SearchValue nvarchar(255) = N’’,
@Page int = 1,
@PageSize int = 20,
@RowCount int output,
@PageCount int output
Có chức năng tìm kiếm và hiển thị danh sách các bài viết dưới dạng phân trang. Trong đó, tham số
@SearchValue là tiêu đề hoặc nội dung của bài viết cần tìm (tìm kiếm tương đối). @Page là trang
cần hiển thị, @PageSize là số dòng dữ liệu được hiển thị trên mỗi trang, tham số đầu ra
@RowCount cho biết tổng số dòng dữ liệu và tham số đầu ra @PageCount cho biết tổng số trang.

if exists( select * from sys.objects where name = 'proc_Posts_Select')
	drop procedure proc_Posts_Select;
go

create procedure proc_Posts_Select
	@SearchValue nvarchar(255) = N'',
	@Page int = 1,
	@PageSize int = 20,
	@RowCount int output,
	@PageCount int output
as
begin
	set nocount on;
	set @SearchValue = '%' + @SearchValue +'%'
	if (@Page<1) set @Page = 1;
	if (@PageSize<1) set @PageSize = 20;
	
	
	select @RowCount=count(*)
	from Posts
	where PostTitle LIKE @SearchValue

	set @PageCount = @RowCount/@PageSize
	if (@RowCount%@PageSize>0) set @PageCount +=1;

	select * from
	(
		select *,ROW_NUMBER()over(order by PostTitle) as RowNumber
		from Posts
		where PostTitle LIKE @SearchValue
	)as t
	where t.RowNumber between (@Page-1)*@PageSize +1 and @Page*@PageSize
	order by PostTitle
		
end
go

--test case:
declare @r int,@p int;
execute proc_Posts_Select
	@SearchValue = N'AT',
	@Page = 1,
	@PageSize = 20,
	@RowCount =@r output,
	@PageCount =@p output;
select @r, @p;

--2dif exists( select * from sys.objects where name ='proc_CountPostByYear')	drop procedure proc_CountPostByYear;--gocreate procedure proc_CountPostByYear	@FromYear int,
	@ToYear intasbegin	set nocount on;	declare @tbl table	(	Year_ int	)	declare @y int	set @y = @FromYear	while( @y <= @ToYear)		begin			insert into @tbl values(@y)			set @y +=1;		end	select t1.Year_, isnull(t2.NumOfPost,0) as NumOfPost, 				isnull(t2.NumOfCmt,0) as NumOfCmt	from @tbl as t1 left join	(		select year(p.CreatedTime) as Year_, count(p.PostId) as NumOfPost,				count(c.CommentId) as NumOfCmt		from Posts as p join Comments as c on p.PostId = c.PostId		group by p.CreatedTime	) as t2	on t1.Year_ = t2.Year_	where t1.Year_ between @FromYear and @ToYearend--go--test caseproc_CountPostByYear
@FromYear =2020,
@ToYear = 2023

select * from Accounts
select * from Posts
select * from Comments

select * from Posts

--3a: Viết các hàm sau đây
a. (1 điểm) func_CountPost(@From date, @To date) có chức năng tính tổng số lượng bài
được viết trong khoảng thời gian từ ngày @From đến ngày @To.

if exists( select * from sys.objects where name='func_CountPost')
	drop function func_CountPost;
go

create function func_CountPost(@From date, @To date)
returns int
as
begin
	declare @Count int

	select @Count=count(*)
	from Posts
	where CreatedTime between @From and @To

	return @Count;
end
go

--test case:
select dbo.func_CountPost('2020/02/02','2023/02/02')


--3b
if exists(select * from sys.objects where name='func_CountPostByYear')
	drop function func_CountPostByYear;
go

create function func_CountPostByYear(@FromYear int, @ToYear int)
returns @tbl table
(
Year_ int,
NumOfPost int,
NumOfCmt int
)
as
begin
	insert into @tbl(Year_,NumOfPost, NumOfCmt)
		select year(p.CreatedTime) as Year_, count(p.PostId) as NumOfPost,				count(c.CommentId) as NumOfCmt		from Posts as p join Comments as c on p.PostId = c.PostId		group by p.CreatedTime

	declare @y int	set @y = @FromYear	while( @y <= @ToYear)		begin			if not exists( select * from @tbl where Year_ = @y)					insert into @tbl values(@y,0,0)			set @y +=1;		end

	return;
end
go

--test case
select * from dbo.func_CountPostByYear(2020,2023)



