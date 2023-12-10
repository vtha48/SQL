--1a Trigger trg_Question_Insert có chức năng bắt lệnh INSERT trên bảng 
Question sao cho khi mỗi khi bổ sung một câu hỏi thì tự động tăng số lượng câu hỏi của tài khoản 
(cột NumOfQuestions trong bảng UserAccount).

if exists( select * from sys.objects where name = 'trg_Question_Insert')
	drop trigger trg_Question_Insert;
go

create trigger trg_Question_Insert
on Question
for insert
as
begin
	set nocount on;

	declare @Username nvarchar(50)
	set @Username = (select Username from inserted)

	update UserAccount
	set NumOfQuestions +=1
	where Username = @Username

end
go

--testcase:
insert into Question(QuestionTitle,QuestionContent,UserName)
values('ABC','B','B')

--1B  Trigger trg_Answer_Insert có chức năng bắt lệnh INSERT trên bảng Answer sao 
cho mỗi khi bổ sung một trả lời thì tự động tăng số lượng câu trả lời của tài khoản (cột 
NumOfAnswers trong bảng UserAccount) và số lượng câu trả lời của câu hỏi (cột 
NumOfAnswers của bảng Question
--
if exists( select * from sys.objects where name = 'trg_Answer_Insert')
	drop trigger trg_Answer_Insert;
go

create trigger trg_Answer_Insert
on Answer
for insert
as
begin
	set nocount on;

	declare @UserName nvarchar(50)
	set @UserName = (select UserName from inserted)

	update UserAccount
	set NumOfAnswers +=1
	where UserName = @UserName

	update Question
	set NumOfAnswers +=1
	where QuestionId in (select QuestionId from inserted)

end
go


--testcase:
insert into Answer(QuestionId,UserName,AnswerContent)
values(2,'A','A')

--2a:proc_Question_Insert
@QuestionTitle nvarchar(255),
2
@QuestionContent nvarchar(2000),
@UserName nvarchar(50),
@QuestionId int output
Có chức năng tạo mới một câu hỏi. Tham số đầu ra @QuestionId trả về mã của câu hỏi được tạo 
mới trong trường hợp thành công; Ngược lại, tham số này trả về giá trị nhỏ hơn hoặc bằng 0 nhằm 
cho biết lý do không tạo được câu hỏi.

if exists( select * from sys.objects where name = 'proc_Question_Insert')
	drop procedure proc_Question_Insert;
go

create procedure proc_Question_Insert
	@QuestionTitle nvarchar(255),
	@QuestionContent nvarchar(2000),
	@UserName nvarchar(50),
	@QuestionId int output
as
begin
	set nocount on;
	if not exists ( select * from Question where QuestionTitle is null)
		begin
			set @QuestionId = 0
			return;
		end

	if not exists ( select * from Question where QuestionContent is null)
		begin
			set @QuestionId = -1
			return;
		end

	if not exists ( select * from UserAccount where UserName = @UserName)
		begin
			set @QuestionId = -2
			return;
		end

	insert into Question(QuestionTitle,QuestionContent,UserName)
	values(@QuestionTitle,@QuestionContent,@UserName)

	set @QuestionId= @@IDENTITY  
end
go

--test case:
declare @q int;
execute proc_Question_Insert
	@QuestionTitle ='ABD',
	@QuestionContent ='E',
	@UserName ='E',
	@QuestionId =@Q output;
SELECT @q


--2B proc_UserAccount_Update
@UserName nvarchar(50),
@FullName nvarchar(100),
@Email nvarchar(50),
@Result nvarchar(255) output
Có chức năng cập nhật thông tin của tài khoản. Nếu việc cập nhật là thành công, tham số đầu ra 
@Result trả về chuỗi rỗng; Ngược lại, tham số này trả về chuỗi cho biết lý do tại sao không cập 
nhật được dữ liệu

if exists( select * from sys.objects where name = 'proc_UserAccount_Update')
	drop procedure proc_UserAccount_Update;
go

create procedure proc_UserAccount_Update
	@UserName nvarchar(50),
	@FullName nvarchar(100),
	@Email nvarchar(50),
	@Result nvarchar(255) output
AS
BEGIN
	SET NOCOUNT ON;
	IF NOT EXISTS ( SELECT * FROM UserAccount WHERE UserName = @UserName)
		BEGIN
			SET @Result = N' K TỒN TẠI NGƯỜI DÙNG NÀY !';
			RETURN;
		END
	

	UPDATE UserAccount
	SET UserName = @UserName, FullName = @FullName, Email = @Email
	WHERE UserName = @UserName

	SET @Result = N'';
END
GO

--TEST CASE:
DECLARE @R nvarchar(255);
EXECUTE proc_UserAccount_Update
	@UserName ='E',
	@FullName ='EE',
	@Email = 'E@gmail.com',
	@Result =@R output;
select @R;


--2c: 
c. (1,5 điểm) proc_Question_Select
@SearchValue nvarchar(255) = N’’,
@Page int = 1,
@PageSize int = 20,
@RowCount int output,
@PageCount int output
Có chức năng tìm kiếm và hiển thị danh sách các câu hỏi dưới dạng phân trang. Trong đó, tham số
@SearchValue là tiêu đề hoặc nội dung của câu hỏi cần tìm (tìm kiếm tương đối). @Page là trang 
cần hiển thị, @PageSize là số dòng dữ liệu được hiển thị trên mỗi trang, tham số đầu ra 
@RowCount cho biết tổng số dòng dữ liệu và tham số đầu ra @PageCount cho biết tổng số trang.
--
if exists( select * from sys.objects where name = 'proc_Question_Select')
	drop procedure proc_Question_Select;
go
create procedure proc_Question_Select
	@SearchValue nvarchar(255) = N'',
	@Page int = 1,
	@PageSize int = 20,
	@RowCount int output,
	@PageCount int output
as
begin
	set nocount on;
	set @SearchValue = '%' + @SearchValue +'%';
	if (@Page<1) set @Page = 1;
	if (@PageSize<1) set @PageSize = 20;

	select @RowCount = count(*)
	from Question
	where QuestionTitle like @SearchValue

	set @PageCount = @RowCount/@PageSize
	if (@RowCount % @PageSize > 0) set @PageCount+=1;
	
	select t.RowNumber, QuestionId, QuestionTitle
	from
		(
			select *, ROW_NUMBER() over (Order by QuestionTitle) as RowNumber
			from Question
			where QuestionTitle like @SearchValue
		) as t
	where t.RowNumber between (@Page-1)*@PageSize +1 and @Page *@PageSize
	order by t.RowNumber


end
go

--test case:  
declare @r int, @p int;
execute proc_Question_Select
	@SearchValue = 'A',
	@Page = 1,
	@PageSize = 20,
	@RowCount = @r output,
	@PageCount = @p output;
select @r, @p;

SELECT * FROM Question

--2D: 
d. (1,5 điểm) proc_CountQuestionByYear
@FromYear int,
@ToYear int
Có chức năng thống kê số lượng câu hỏi và số lượng câu trả lời của từng năm trong khoảng thời 
gian từ năm @FromYear đến năm @ToYear. Yêu cầu kết quả thống kê phải hiển thị đủ tất cả các 
năm (kể cả những năm không có câu hỏi hay câu trả lời).

--
if exists( select * from sys.objects where name = 'proc_CountQuestionByYear')
	drop procedure proc_CountQuestionByYear;
go
create procedure proc_CountQuestionByYear
	@FromYear int,
	@ToYear int
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @TBL TABLE
		(
			YEAR_ INT
		)

		DECLARE @Y INT
		
		SET @Y = @FromYear;
		
		WHILE( @y <= @ToYear)
			BEGIN
			INSERT INTO @TBL VALUES(@Y)
			SET @y +=1;
			END

		SELECT t1.YEAR_,isnull(t2.CountOfQuestion,0) as CountOfQuestion,
						isnull(t3.CountOfAnswer,0) as CountOfAnswer

		from @tbl as t1
			left join
			(
				select year(AskedTime) as Year_, count(QuestionId) as CountOfQuestion
				from Question
				where year(AskedTime) between @FromYear and @ToYear
				group by year(AskedTime)
			) 
			as t2 on t1.YEAR_ = t2.Year_
			left join
			(
				select year(AnsweredTime) as Year_, count(AnswerId) as CountOfAnswer
				from Answer
				where year(AnsweredTime) between @FromYear and @ToYear
				group by year(AnsweredTime)
			) as t3 on t1.YEAR_ = t3.Year_


END
GO

--TEST CASE: 
exec proc_CountQuestionByYear
	@FromYear = 2010,
	@ToYear =2025


--3a: các hàm sau đây
a. (1 điểm) func_CountAnswers(@From date, @To date) có chức năng tính tổng số
lượng câu trả lời được đăng trong khoảng thời gian từ ngày @From đến ngày @To

if exists( select * from sys.objects where name = 'func_CountAnswers')
	drop function func_CountAnswers;
go

create function func_CountAnswers(@From date, @To date)
returns int
as
begin
	declare @Count int

	select @Count = count(*)
	from Answer
	where AnsweredTime between @From and @To

	return @Count;
end
go

--test case:
select dbo.func_CountAnswers('2020/02/02','2023/02/03')

--3b:  func_CountQuestionByYear(@FromYear int, @ToYear int) trả về bảng 
thống kê số lượng câu hỏi và số lượng câu trả lời của từng năm trong khoảng thời gian từ năm 
@FromYear đến năm @ToYear. Yêu cầu kết quả thống kê phải hiển thị đủ tất cả các năm (kể cả
những năm không có câu hỏi hay câu trả lời).

--
if exists( select * from sys.objects where name = 'func_CountQuestionByYear')
	drop function func_CountQuestionByYear;
go
create function func_CountQuestionByYear(@FromYear int, @ToYear int)
returns @tbl table
(
Year_ int,
CountOfAnswer int,
CountOfQuestion int
)
as
begin
	DECLARE @TBL_Year TABLE (Year_ int)
    DECLARE @Y int = @FromYear

    --Thêm các năm vào bảng tạm
    WHILE @Y <= @ToYear
    BEGIN
        INSERT INTO @TBL_Year VALUES (@Y)
        SET @Y += 1
    END
	insert into @tbl(Year_,CountOfQuestion,CountOfAnswer)
		SELECT t1.YEAR_,isnull(t2.CountOfQuestion,0) as CountOfQuestion,
						isnull(t3.CountOfAnswer,0) as CountOfAnswer

		from @TBL_Year as t1
			left join
			(
				select year(AskedTime) as Year_, count(QuestionId) as CountOfQuestion
				from Question
				where year(AskedTime) between @FromYear and @ToYear
				group by year(AskedTime)
			) 
			as t2 on t1.YEAR_ = t2.Year_
			left join
			(
				select year(AnsweredTime) as Year_, count(AnswerId) as CountOfAnswer
				from Answer
				where year(AnsweredTime) between @FromYear and @ToYear
				group by year(AnsweredTime)
			) as t3 on t1.YEAR_ = t3.Year_
	return;
end
go

--test case:
select * from dbo.func_CountQuestionByYear(2019,2023)